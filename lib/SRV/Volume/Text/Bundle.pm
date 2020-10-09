package SRV::Volume::Text::Bundle;

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
    pages_ranges
    total_pages
    output_filename 
    progress_filepath 
    cache_dir
    download_url
    marker
    restricted 
    rotation 
    limit 
    watermark 
    is_partial 
    attachment
    attachment_filename
    id
    super
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

use Digest::SHA qw(sha256_hex);

use utf8;

# our $script_content_type = 'text/plain';
our $script_content_type = 'application/javascript';
our $content_type = {
    'text' => 'text/plain',
    'zip'       => 'application/zip'
};

our $content_extension = {
    'text' => 'txt',
    'zip'  => 'zip'
};

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    
    $self->watermark(1) unless ( defined $self->watermark );

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

    $self->_authorize($env);

    if ( $self->restricted ) {
        my $req = Plack::Request->new($env);
        my $res = $req->new_response(403);
        $res->content_type("text/html");
        $res->body(qq{<html><body>Restricted</body></html>});
        return $res;
    }

    if ( $req->param('callback') ) {
        return $self->_background($env);
    }

    # format=zip cannot be streamed
    if ( ! defined $self->output_filename || ! -s $self->output_filename || $req->param('force') ) {
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
    
    my $progress_filename_url = SRV::Utils::get_download_status_url($self, 'text');

    my $download_url = SRV::Utils::get_download_url($self, "text");
    $self->download_url($download_url);

    my $callback = $req->param('callback');

    my $total_pages = $self->total_pages;

    my $updater = $self->_updater({
        download_url => $download_url,
        filepath => $progress_filepath,
        total_pages => $total_pages
    });

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
    my @cmd = ( "../bin/start.sh", $$, "text", $cache_filename );
    push @cmd, "--id", $id;
    if ( $self->is_partial ) {
        foreach my $seq ( @{ $self->pages } ) {
            push @cmd, "--seq", $seq;
        }
    }
    push @cmd, "--progress_filepath", $progress_filepath;
    push @cmd, "--output_filename", $cache_filename;
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
    my $headers = [ "Content-Type", $$content_type{$self->format} ];
    my $filename = $self->attachment_filename;
    my $disposition = qq{inline; filename=$filename};
    if ( $self->attachment ) {
        $disposition = qq{attachment; filename=$filename};
    }
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
    my $ar = $C->get_object('Access::Rights');
    my $gId = $mdpItem->GetId();

    unless ( $self->restricted ) {
        # my $full_book_restricted = SRV::Utils::under_server() ? $ar->get_full_PDF_access_status($C, $gId) : 'allow';
        my $full_book_restricted = $ar->get_full_PDF_access_status($C, $gId);
        $full_book_restricted = 'allow' if ( defined $self->super && $self->super );
        if ( $full_book_restricted ne 'allow' ) {
            if ( $self->is_partial ) {
                # limit these to just the first five to prevent mass downloading
                $self->pages([ $self->pages->[0] ]);
            } else {
                # limit to the default sequence
                $self->pages([ $mdpItem->GetFirstPageSequence ]);
            }
        }
    }

    my $updater = new SRV::Utils::Progress 
        filepath => $self->progress_filepath, total_pages => $self->total_pages,
        download_url => $self->download_url,
        type => ( $self->format eq 'zip' ? 'zip archive' : 'combined text file' );

    my $class = q{Process::Volume::Text::Bundle};

    $class = Plack::Util::load_class($class);
    my $process = $class->new(
        mdpItem => $mdpItem,
        output_filename => $self->output_filename,
        progress_filepath => $self->progress_filepath,
        cache_dir => $self->cache_dir || SRV::Utils::get_cachedir(),
        display_name => $self->display_name,
        institution => $self->institution,
        access_stmts => $self->access_stmts,
        restricted => $self->restricted,
        proxy => $self->proxy,
        download_url => $self->download_url,
        handle => $self->handle,       
        limit => $self->limit,
        watermark => $self->watermark,
        format => $self->format,
        pages => $self->pages,
        is_partial => $self->is_partial,
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
        format => undef,
        output_filename => undef,
        progress_filepath => undef,
        attachment => undef,
        download_url => undef,
    );

    unless ( SRV::Utils::under_server() ) {
        # this can only be passed from the command line
        $params{super} = undef;
    }

    SRV::Utils::parse_env(\%params, [qw(file format output_filename)], $req, $args);

    foreach my $param ( keys %params ) {
        $self->$param($params{$param}) if ( $params{$param} );
    }

    my $attachment_filename = $mdpItem->GetId();

    # define pages
    my $slice;
    my $file = $self->file;
    if ( $file && $file =~ m,^seq:, ) {
        $file =~ s,^seq:,,;

        # expand page ranges
        if ( $file =~ m,\-, ) {
            $self->pages_ranges($file);
            $file = join(',', @{ SRV::Utils::range2seq($file) });
        }

        $self->pages([ map { $mdpItem->GetValidSequence($_) } split(/,/, $file) ]);
        $self->is_partial(1);
        if ( $self->pages_ranges ) {
            $slice = "-" . $self->pages_ranges;
            $slice =~ s{,}{-}g;
        } else {
            $slice = "-" . join("-", @{ $self->pages });
        }
        $attachment_filename .= $slice;
    } else {
        my $pageinfo_sequence = $mdpItem->Get('pageinfo')->{'sequence'};
        $self->pages([ sort { int($a) <=> int($b) } keys %{ $pageinfo_sequence } ]);
        $self->is_partial(0);
        # full book downloads download by default
        unless ( defined $self->attachment ) {
            $self->attachment(1);
        }
    }

    $attachment_filename .= "-" . time() . "." . $$content_extension{$self->format};
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
        my ( $fh, $filename ) = tempfile( 
            DIR => $cache_dir, 
            SUFFIX => $$content_extension{$self->format}, 
            CLEANUP => 0 
        );
        $self->output_filename($filename);
    }

}

sub _validate_params {
    my ( $self ) = @_;

}

sub _authorize {
    my $self = shift;
    my $env = shift;

    $self->restricted(0) unless ( SRV::Utils::under_server() );

    unless ( defined $self->restricted ) {

        my $C = $$env{'psgix.context'};
        my $mdpItem = $C->get_object('MdpItem');
        my $ar = $C->get_object('Access::Rights');
        my $gId = $mdpItem->GetId();

        my $final_access_status = $ar->assert_final_access_status($C, $gId);
        my $download_access_status = $ar->get_single_page_PDF_access_status($C, $gId);

        my $restricted = ! ( ( $final_access_status eq 'allow' ) && ( $download_access_status eq 'allow' ) );
            
        $self->restricted($restricted);
    }
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

sub _updater {
    my $self = shift;
    my %params = @_;
    return new SRV::Utils::Progress
        type => ( $self->format eq 'zip' ? 'zip archive' : 'combined text file' ),
        %params;
}

1;
