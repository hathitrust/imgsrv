package SRV::Volume::EPUB;

use strict;
use warnings;

use parent qw( Plack::Component );

use Plack::Request;
use Plack::Response;
use Plack::Util;
use Plack::Util::Accessor qw( 
    output_fh 
    access_stmts 
    display_name 
    institution 
    proxy 
    handle 
    format 
    file
    pages 
    total_pages
    searchable 
    output_filename 
    progress_filepath 
    cache_dir
    download_url
    marker
    restricted 
    rotation 
    limit 
    target_ppi 
    watermark 
    max_dim
    is_partial 
    attachment_filename
    id
);

use Identifier;
use Utils;
use Debug::DUtils;

use SRV::Globals;
use SRV::Utils;

use Data::Dumper;

use IO::File;

use File::Basename qw(basename dirname fileparse);
use File::Path qw(remove_tree);
use File::Temp qw(tempfile);
use POSIX qw(strftime);
use Time::HiRes;

use Access::Statements;

use Image::ExifTool;

use Digest::SHA qw(sha256_hex);

use utf8;

# our $script_content_type = 'text/plain';
our $script_content_type = 'application/javascript';
our $content_type = 'application/epub+zip';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    
    # $self->format('volume') unless ( $self->format );
    $self->watermark(1) unless ( defined $self->watermark );
    $self->target_ppi(0) unless ( defined $self->target_ppi );
    $self->searchable(1) unless ( defined $self->searchable );

    $self->is_partial(0);

    $self;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    if ( my $num_attempts = $req->param('num_attempts') ) {
        # we are really just logging and leaving
        soft_ASSERT($num_attempts == 0, qq{Downloader lost track of progress: $num_attempts});
        my $res = $req->new_response(204);
        return $res->finalize;
    }

    $self->_fill_params($env);

    if ( $req->param('callback') ) {
        return $self->_background($env);
    }

    # EPUBs cannot be streamed; so if we're not backgrounding, 
    if ( ! defined $self->output_filename || ! -s $self->output_filename || $req->param('force') ) {
        print STDERR "RUNNING\n";
        $self->run($env);
    }

    return $self->_stream($env);
}

sub _background {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $id = $mdpItem->GetId();

    my $marker = $self->marker;

    # this code should go elsewhere...
    my $cache_dir = SRV::Utils::get_cachedir();
    my $cache_filename = $self->output_filename;

    my $progress_filepath = $self->progress_filepath;
    die "SHOULD HAVE A FILE PATH" unless ( $progress_filepath );
    
    my $progress_filename_url = SRV::Utils::get_download_status_url($self, 'epub');

    my $download_url = SRV::Utils::get_download_url($self, "epub");
    $self->download_url($download_url);

    my $callback = $req->param('callback');

    my $total_pages = $self->total_pages;

    my $updater = new SRV::Utils::Progress
        download_url => $download_url,
        filepath => $progress_filepath,
        total_pages => $total_pages,
        type => 'EPUB';

    if ( $req->param('stop') ) {
        $updater->cancel;

        my $res = $req->new_response(200);
        $res->content_type($script_content_type);
        $res->body(qq{$callback('$progress_filename_url', '$download_url', $total_pages);});
        return $res->finalize;   
    }

    if ( -s $cache_filename && ! $updater->is_cancelled ) {

        # requested with a callback; we have to generate a one-time
        # progress file to invoke the callback so it can present the right UI.
        # if we send data, the PDF is downloaded, but the client app
        # thinks something went awry.

        $updater->finish;

        my $res = $req->new_response(200);
        $res->content_type($script_content_type);
        $res->body(qq{$callback('$progress_filename_url', '$download_url', $total_pages);});
        return $res->finalize;

    }

    if ( $updater->is_cancelled ) {
        # this would have been left over
        $updater->reset;
    }

    # check that we're not already building a PDF
    if ( $updater->in_progress ) {
        my $res = $req->new_response(200);
        $res->content_type($script_content_type);
        $res->body(qq{$callback('$progress_filename_url', '$download_url', $total_pages);});
        return $res->finalize;
    }

    # we're only here _because_ we're in the background, with a callback; fork the child and keep going
    my @cmd = ( "../bin/start.sh", $$, "epub", $cache_filename );
    push @cmd, "--id", $id;
    if ( $self->is_partial ) {
        foreach my $seq ( @{ $self->pages } ) {
            push @cmd, "--seq", $seq;
        }
    }
    push @cmd, "--progress_filepath", $progress_filepath;
    push @cmd, "--output_filename", $cache_filename;
    # push @cmd, "--cache_dir", $self->cache_dir;
    push @cmd, "--download_url", $download_url;

    my $retval = SRV::Utils::run_command($env, \@cmd);

    $updater->initialize;

    my $res = $req->new_response(200);
    $res->content_type($script_content_type);
    my $body = [qq{$callback('$progress_filename_url', '$download_url', $total_pages, '$retval');}];
    $res->body($body);
    return $res->finalize;

}

sub _stream {
    my ( $self, $env ) = @_;

    # return the file
    my $fh;
    my $cache_dir = SRV::Utils::get_cachedir('download_cache_dir');
    if ( $self->output_filename =~ m,^$cache_dir, ) {
        # make this a vanishing file; only clean up its containiner directory if 
        # it's a new $marker format
        $fh = new SRV::Utils::File $self->output_filename, ( $self->output_filename =~ m,$SRV::Globals::gMarkerPrefix, );
    } else {
        $fh = new IO::File $self->output_filename;
    }

    my $req = Plack::Request->new($env);
    my $res = $req->new_response(200);

    $res->headers($self->_get_response_headers);
    $res->body($fh);

    # unlink the progress file IF we're calling from the web
    unless ( $ENV{PSGI_COMMAND} ) {
        remove_tree $self->progress_filepath if ( $self->progress_filepath && -d $self->progress_filepath );
    }
    return $res->finalize;
}

sub _get_response_headers {
    my $self = shift;
    my $headers = [ "Content-Type", $content_type ];
    my $filename = $self->attachment_filename;
    my $disposition = qq{attachment; filename=$filename};
    push @$headers, "Content-disposition", $disposition;
    if ( defined $self->output_filename && -f $self->output_filename ) {
        push @$headers, "Content-length", ( -s $self->output_filename );
    }
    return $headers;
}

sub run {
    my $self = shift;
    my $env = shift;
    my %args = @_;

    $self->_fill_params(\%args) if ( %args );
    $self->_validate_params();

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    $self->restricted(0) unless ( Debug::DUtils::under_server() );

    unless ( defined $self->restricted ) {
        my $restricted;
        $restricted = $C->get_object('Access::Rights')->assert_final_access_status($C, $gId) ne 'allow';
        unless ( $restricted || scalar @{ $self->pages } ) {
            # not restricted, and asking for full book
            my $full_book_restricted = $C->get_object('Access::Rights')->get_full_PDF_access_status($C, $gId);
            if ( $full_book_restricted ne 'allow' ) {
                # change the pages to the default sequence
                $self->pages([ $mdpItem->GetFirstPageSequence ]);
            }
        }
        $self->restricted($restricted);
    }

    my $updater = new SRV::Utils::Progress 
        filepath => $self->progress_filepath, total_pages => $self->total_pages,
        download_url => $self->download_url,
        type => 'EPUB';

    my $class = q{Process::Volume::EPUB};
    if ( $self->format ) {
        $class .= "::" . uc $self->format;
    }

    $class = Plack::Util::load_class($class);
    my $process = $class->new(
        mdpItem => $mdpItem,
        output_filename => $self->output_filename,
        progress_filepath => $self->progress_filepath,
        cache_dir => $self->cache_dir,
        display_name => $self->display_name,
        institution => $self->institution,
        access_stmts => $self->access_stmts,
        restricted => $self->restricted,
        proxy => $self->proxy,
        download_url => $self->download_url,
        handle => $self->handle,       
        limit => $self->limit,
        rotation => $self->rotation,
        target_ppi => $self->target_ppi,
        watermark => $self->watermark,
        # max_dim => $self->max_dim,
        pages => $self->pages,
        updater => $updater,
    );
    $process->process($env);
}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $id = $mdpItem->GetId();

    my $req = Plack::Request->new($env);
    my %params = (
        file => undef,
        rotation => '0',
        format => undef,
        output_filename => undef,
        progress_filepath => undef,
        download_url => undef,
    );

    SRV::Utils::parse_env(\%params, [qw(file rotation format output_filename)], $req, $args);

    foreach my $param ( keys %params ) {
        $self->$param($params{$param}) if ( $params{$param} );
    }

    my $attachment_filename = $mdpItem->GetId();

    # define pages
    my $file = $self->file;
    if ( $file && $file =~ m,^seq:, ) {
        $file =~ s,^seq:,,;
        $self->pages([ split(/,/, $file) ]);
        $self->is_partial(1);
        $attachment_filename .= "-" . join('-', @{ $self->pages });
    } else {
        my $pageinfo_sequence = $mdpItem->Get('pageinfo')->{'sequence'};
        $self->pages([ sort { int($a) <=> int($b) } keys %{ $pageinfo_sequence } ]);
        $self->is_partial(0);
    }

    $attachment_filename .= ".epub";
    $self->attachment_filename($attachment_filename);

    $self->total_pages(scalar @{ $self->pages });

    $self->id($mdpItem->GetId());
    $self->handle(SRV::Utils::get_itemhandle($mdpItem));

    # add user details
    my $auth = $C->get_object('Auth');
    my $rights = $C->get_object('Access::Rights');
    $self->display_name($auth->get_user_display_name($C, 'unscoped'));
    $self->institution($auth->get_institution_name($C));
    $self->access_stmts(SRV::Utils::get_access_statements($mdpItem));
    ## only set this if the book is in copyright
    unless ( $rights->public_domain_world_creative_commons($C, $self->id) ) {
        $self->proxy($auth->get_PrintDisabledProxyUserSignature($C));
    }

    $self->download_url($req->param('download_url')) if ( $req->param('download_url') );

    my $identifier;
    unless ( $identifier = $req->env->{REMOTE_USER} ) {
        my $ses = $C->get_object('Session', 1);
        $identifier = $ses ? $ses->get_session_id() : ( $$ . time() );
    }

    my $volume_identifier = Identifier::get_pairtree_id_with_namespace($self->id);
    my $user_volume_identifier = $identifier .= '#' . $volume_identifier;

    my $marker = $req->param('marker');
    if ( ! $marker && defined $req->param('callback') ) {
        # only define a marker IF we're initiating a callback to avoid
        # creating spurious files
        $marker = $user_volume_identifier;

        ## $marker .= "-$slice" if ( $slice );
        $marker .= "#EPUB";
        $marker = $SRV::Globals::gMarkerPrefix . sha256_hex($marker);
    }
    $self->marker($marker);

    my $cache_dir;
    if ( $marker ) {

        # handle earlier version of $marker
        if ( $marker =~ m,^$SRV::Globals::gMarkerPrefix, ) {
            $cache_dir = SRV::Utils::get_cachedir('download_cache_dir') . $marker . '/'; 
        } else {
            $cache_dir = SRV::Utils::get_cachedir('download_cache_dir') . $volume_identifier . '/';
        }
        unless ( $self->output_filename ) {
            # my $cache_filename = $cache_dir . Identifier::id_to_mdp_path($id) . $slice . "__$marker" . ".pdf";
            my $cache_filename = $cache_dir . $marker . ".epub";
            Utils::mkdir_path( dirname($cache_filename), $SRV::Globals::gMakeDirOutputLog );
            $self->output_filename($cache_filename);
        }

        unless ( $self->progress_filepath || ( $req->param('attachment') && $req->param('attachment') eq '0' ) ) {
            # my $download_progress_cache_base = SRV::Utils::get_download_progress_base();
            # my $progress_filename = $download_progress_cache_base . Identifier::id_to_mdp_path($id) . $slice . "__" . $marker . ".html";
            my $progress_filepath = $cache_dir . $marker  . "__progress";
            Utils::mkdir_path( ($progress_filepath), $SRV::Globals::gMakeDirOutputLog );

            $self->progress_filepath($progress_filepath);
        }


    } elsif ( ! $self->output_filename ) {
        # we do need something concrete for EPUBs
        $cache_dir = SRV::Utils::get_cachedir('download_cache_dir') . $volume_identifier . '/';
        Utils::mkdir_path( $cache_dir, $SRV::Globals::gMakeDirOutputLog );
        my ( $fh, $filename ) = tempfile( DIR => $cache_dir, SUFFIX => '.epub', CLEANUP => 0 );
        # my $filename = $cache_dir . $maker .  '.epub';
        $self->output_filename($filename);
    }

    $self->max_dim(SRV::Utils::get_max_dimension($mdpItem));

}

sub _validate_params {
    my ( $self ) = @_;

}

sub _get_default_seq {
    my $self = shift;
    my $mdpItem = shift;
    my $seq;
    $seq = $mdpItem->HasTitleFeature();
    unless ( $seq ) {
        $seq = $mdpItem->HasTOCFeature();
    }
    return $seq;
}

1;
