package SRV::Volume::PDF;
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
    file
    format
    pages
    pages_ranges
    total_pages
    searchable
    output_filename
    stamp_filename
    progress_filepath
    download_url
    marker
    restricted
    rotation
    limit
    target_ppi
    quality
    watermark
    max_dim
    is_partial
    attachment
    attachment_filename
    super
    id
);

use Identifier;
use Utils;
use Debug::DUtils;
use DbUtils;

use SRV::Globals;
use SRV::Utils;

use Data::Dumper;

use IO::File;

use File::Basename qw(basename dirname fileparse);
use File::Path qw(remove_tree);
use POSIX qw(strftime);
use Time::HiRes;

use Access::Statements;
use List::MoreUtils qw(any);

use Image::ExifTool;

use Digest::SHA qw(sha256_hex);

use Process::Watermark::PDF;

use utf8;

# our $script_content_type = 'text/plain';
our $script_content_type = 'application/javascript';
our $content_type = 'application/pdf';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    # $self->format('volume') unless ( $self->format );
    $self->watermark(1) unless ( defined $self->watermark );
    $self->target_ppi(0) unless ( defined $self->target_ppi );
    $self->rotation(0) unless ( defined $self->rotation );
    $self->searchable(1) unless ( defined $self->searchable );
    $self->quality('default') unless ( defined $self->quality );
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

    if ( $req->param('callback') ) {
        return $self->_background($env);
    }

    if ( defined $self->output_filename && -s $self->output_filename ) {
        # file exists; return and delete
        return $self->_stream($env);
    }

    # stream as the PDF is built; always do this if we've been invoked
    # as a CGI and don't have a callback

    $$env{__debug_jpeg2000_exif} = DEBUG('exif');

    return sub {
        my $responder = shift;

        my $status = ( Debug::DUtils::under_server() && $self->restricted ) ? 403 : 200;

        my $writer = $responder->([$status, $self->_get_response_headers]);
        my $fh;

        if ( ! $self->output_filename || Debug::DUtils::under_server() ) {
            # streaming
            $fh = new SRV::Utils::Stream responder => $responder, writer => $writer;
            $self->output_filename($fh);
        }
        $self->run($env);
        $self->_log($env) unless ( $ENV{PSGI_COMMAND} );
    }
}

sub _get_response_headers {
    my $self = shift;
    my $headers = [ "Content-Type", $content_type ];
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

sub _background {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $id = $mdpItem->GetId();

    if ( $self->restricted ) {
        my $res = $req->new_response(403);
        $res->content_type("text/html");
        $res->body(qq{<html><body>Restricted</body></html>});
        return $res->finalize;
    }

    my $marker = $self->marker;

    # this code should go elsewhere...
    my $cache_filename = $self->output_filename;

    my $progress_filepath = $self->progress_filepath;
    my $progress_filename_url = SRV::Utils::get_download_status_url($self, 'pdf');

    my $download_url = SRV::Utils::get_download_url($self, "pdf");
    $self->download_url($download_url);

    my $callback = $req->param('callback');

    my $total_pages = $self->total_pages;

    my $updater = new SRV::Utils::Progress
        download_url => $download_url,
        filepath => $progress_filepath,
        total_pages => $self->total_pages;

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
    my @cmd = ( "../bin/start.sh", $$, "pdf", $cache_filename );
    push @cmd, "--id", $id;
    if ( $self->is_partial ) {
        if ( $self->pages_ranges ) {
            push @cmd, "--seq", $self->pages_ranges;
        } else {
            foreach my $seq ( @{ $self->pages } ) {
                push @cmd, "--seq", $seq;
            }
        }
    }
    push @cmd, "--progress_filepath", $progress_filepath;
    push @cmd, "--output_filename", $cache_filename;
    push @cmd, "--download_url", $$self{download_url};

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
    my $cache_dir = SRV::Utils::get_cachedir('download_cache_dir');
    my $fh;
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
    $self->_log($env);
    return $res->finalize;
}

sub run {
    my $self = shift;
    my $env = shift;
    my %args = @_;

    $self->_fill_params(\%args) if ( %args );
    $self->_validate_params();

    # calculate output_filename
    ### $self->_setup_output_filename($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $ar = $C->get_object('Access::Rights');
    my $gId = $mdpItem->GetId();

    unless ( defined $self->restricted ) {
        $self->_authorize($env);
    }

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
        } elsif ( 0 && $self->is_partial && $self->total_pages > 5 && Debug::DUtils::under_server() ) {
            # limit these to just the first five to prevent mass downloading via lighter choke policies
            $self->pages([ @{$self->pages}[0..4] ]);
        }

    }

    print STDERR "PAGES = " . Data::Dumper::Dumper($self->pages) if ( exists $ENV{DEBUG_PAGES} );

    my $updater = new SRV::Utils::Progress
        filepath => $self->progress_filepath, total_pages => $self->total_pages,
        download_url => $self->download_url;

    my $stamper = new Process::Watermark::PDF
        mdpItem => $mdpItem,
        display_name => $self->display_name,
        institution => $self->institution,
        access_stmts => $self->access_stmts,
        proxy => $self->proxy,
        handle => $self->handle,
        target_ppi => $self->target_ppi,
        watermark => $self->watermark,
        debug => (defined $$env{DEBUG} && $$env{DEBUG} =~ m,marginalia,) || 0,
        output_filename => $self->stamp_filename;
    $stamper->run;

    my $classes = [ 'Process::Volume::PDF' ];
    if ( $mdpItem->HasServeablePDF ) {
        unshift @$classes, 'Process::PDF';
    }

    foreach my $class_name ( @$classes ) {
        if ( $self->format ) {
            $class_name .= "::" . uc $self->format;
        }
        my $class = Plack::Util::load_class($class_name);
        eval {
            my $processor = $class->new(
                mdpItem => $mdpItem,
                output_filename => $self->output_filename,
                restricted => $self->restricted,
                handle => $self->handle,
                limit => $self->limit,
                is_partial => $self->is_partial,
                rotation => $self->rotation,
                target_ppi => $self->target_ppi || 0,
                quality => $self->quality,
                max_dim => $self->max_dim,
                pages => $self->pages,
                searchable => $self->searchable,
                updater => $updater,
                stamper => $stamper,
            );
            $processor->process($env);
        };
        my $err = $@;
        last unless ( $err );
        print STDERR "COULD NOT RUN $class_name : $err\n";
    }

    $stamper->cleanup;
}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    my $req = Plack::Request->new($env);

    my %params = (
        file => undef,
        rotation => '0',
        format => undef,
        output_filename => undef,
        progress_filepath => undef,
        attachment => undef,
        download_url => undef,
        target_ppi => undef,
        quality => 'default',
    );

    unless ( SRV::Utils::under_server() ) {
        # this can only be passed from the command line
        $params{super} = undef;
    }

    SRV::Utils::parse_env(\%params, [qw(file rotation format)], $req, $args);

    foreach my $param ( keys %params ) {
        $self->$param($params{$param});
    }

    my $attachment_filename = $mdpItem->GetId();
    my $slice = "";

    # define pages
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
    $attachment_filename .= "-" . time() .  ".pdf";
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

        $marker .= "-$slice" if ( $slice );
        $marker .= "#PDF";
        $marker = $SRV::Globals::gMarkerPrefix . sha256_hex($marker);
    }
    $self->marker($marker);

    if ( $marker ) {

        my $cache_dir;
        # handle earlier version of $marker
        if ( $marker =~ m,^$SRV::Globals::gMarkerPrefix, ) {
            $cache_dir = SRV::Utils::get_cachedir('download_cache_dir') . $marker . '/'; 
        } else {
            $cache_dir = SRV::Utils::get_cachedir('download_cache_dir') . $volume_identifier . '/';
        }
        unless ( $self->output_filename ) {
            # my $cache_filename = $cache_dir . Identifier::id_to_mdp_path($id) . $slice . "__$marker" . ".pdf";
            my $cache_filename = $cache_dir . $marker . ".pdf";
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

    }

    # the stamp filename has to be distinct from the working directory set up when you have a $marker
    # because streaming does not create a $marker
    my $stamp_filename = SRV::Utils::get_cachedir('download_cache_dir') . sha256_hex($user_volume_identifier) . time() . '__stamp.pdf';
    Utils::mkdir_path( dirname($stamp_filename), $SRV::Globals::gMakeDirOutputLog );
    $self->stamp_filename($stamp_filename);

    $self->max_dim(SRV::Utils::get_max_dimension($mdpItem));

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

sub _log {
    my ( $self, $env ) = @_;

    my $mode = ref($self->output_filename) eq q{SRV::Utils::Stream} ? 'streaming' : 'download';

    my $message = [];

    if ( $self->restricted ) {
        push @$message, [ 'access', 'failure' ];
    }

    # my @message = ( qq{mode=$mode}, q{is_partial=} . $self->is_partial );
    push @$message, ['mode',$mode], ['is_partial', $self->is_partial];
    if ( $self->is_partial ) {
        # push @message, q{seq=} . join(",", @{ $self->pages });
        push @$message, ['seq', join(",", @{ $self->pages })];
    }

    if ( $mode eq 'download' ) {
        push @$message, [ 'content_length', -s $self->output_filename ];
    } else {
        push @$message, [ 'content_length', $self->output_filename->tell ];
    }

    # SRV::Utils::log_string('downloads', join('|', @message));
    SRV::Utils::log_string('downloads', $message);
    $$env{'psgix.imgsrv.logged'} = 1;

    unless ( $self->is_partial ) {
        $self->_log_ga($env, $mode);
    }
}

sub _log_ga {
    my ( $self, $env, $mode ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $config = $C->get_object('MdpConfig');
    my $sess = $C->get_object('Session', 1);
    my $session_id = ref($sess) ? $sess->get_session_id() : $ENV{REMOTE_ADDR};

    require Net::Google::Analytics::MeasurementProtocol;
    require UUID::Tiny;

    my $debug = 0;
    my $ga = Net::Google::Analytics::MeasurementProtocol->new(
                tid => $config->get('imgsrv_ga_tracking_code'), 
                cid => $config->get('imgsrv_client_id'),
                ua  => 'HathiTrust/imgsrv',
                an => 'imgsrv',
                debug => $debug,
            );

    my ( $digitization_source, $collection_source ) = SRV::Utils::get_sources($mdpItem);
    my @dp = ( qq{/cgi/imgsrv-download-pdf/} );
    push @dp, $collection_source, "/", $self->id();
    push @dp, '?mode=' . $mode;
    # push @dl, '?id=' . $self->id();
    if ( $self->is_partial ) {
        foreach my $seq ( @{ $self->pages } ) {
            push @dp, '&seq=' . $seq;
        }
    }
    my $dp = join('', @dp);
    my $dl = ( $ENV{SERVER_PORT} eq 443 ? 'https://' : 'http://' ) . $ENV{SERVER_NAME} . $dp;

    # and then build up cd2
    my $cd2 = [];

    my $dbh = $C->get_object('Database')->get_DBH($C);

    my $statement = qq{SELECT MColl_ID FROM mb_coll_item WHERE extern_item_id=?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $self->id());

    foreach my $row ( @{ $sth->fetchall_arrayref() } ) {
        push @$cd2, $$row[0];
    }
    $cd2 = join('|', @$cd2);

    my $cid = UUID::Tiny::create_uuid_as_string(5, $session_id);
    my $res = $ga->send(
        'pageview', {
            dt => $mdpItem->GetFullTitle(),
            ds => 'imgsrv', 
            dh => $ENV{SERVER_NAME},
            dl => $dl,
            dp => $dp,
            cd => $dl,
            cid => $cid,
            cd2 => $cd2,
            ua  => $ENV{HTTP_USER_AGENT},
            uip => ( $ENV{REMOTE_ADDR} || q{127.0.0.1} ),
        }
    );

    print STDERR $res->content if ( $debug );
}

1;
