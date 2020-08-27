package SRV::Article::PDF;

use parent qw( Plack::Component SRV::Article::Base );

use strict;
use warnings;

use Plack::Request;
use Plack::Response;
use Plack::Util;
use Plack::Util::Accessor qw( 
    working_dir
    output_filename
    progress_filename
    download_url
    access_stmts 
    display_name 
    institution 
    proxy 
    handle 
    marker
    restricted
);

use Identifier;
use Utils;
use Debug::DUtils;

use SRV::Globals;
use SRV::Utils;

use SRV::Article::HTML;

use Data::Dumper;

use IO::File;

use File::Basename qw(basename dirname fileparse);
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Slurp;
use Data::Dumper;
use List::MoreUtils qw(any);
use POSIX qw(strftime);
use Time::HiRes;

use Access::Statements;

use Process::Article::PDF;

use utf8;

# our $script_content_type = 'text/plain';
our $script_content_type = 'application/javascript';
our $content_type = 'application/pdf';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    
    $self;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    $self->_fill_params($env);

    if ( $req->param('callback') ) {
        return $self->_background($env);
    }

    # the alternate test really needs to come here, before we set up 
    # for streaming
    if ( my $fileid = $self->_get_alternate($mdpItem) && ! $req->param('noalt') ) {
        # extract it to output_filename...?
        my $alt_filename = $mdpItem->GetFilePathMaybeExtract($fileid);
        $self->output_filename($alt_filename);
    }

    if ( defined $self->output_filename && -f $self->output_filename ) {
        # file exists; return and delete
        return $self->_stream($env);
    }

    # stream as the PDF is built; always do this if we've been invoked
    # as a CGI and don't have a callback

    return sub {
        my $responder = shift;

        my $writer = $responder->([200, [ "Content-Type", $content_type]]);
        my $fh;

        if ( ! $self->output_filename || Debug::DUtils::under_server() ) {
            # streaming
            $fh = new SRV::Utils::Stream headers => [ 'Content-type', $content_type ], responder => $responder, writer => $writer;
            $self->output_filename($fh);
        }
        $self->run($env);
    }

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

    my $progress_filename = $self->progress_filename;
    
    my $progress_filename_url = $progress_filename;
    $progress_filename_url =~ s,$ENV{SDRROOT},,; 

    my $download_url = qq{/cgi/imgsrv2/download/epub};
    $download_url .= qq{/$id};

    if ( $self->is_partial && scalar @{ $self->pages } ) {
        $download_url .= qq{/seq:} . join(',', @{ $self->pages });
    }

    $download_url .= '?marker=' . $marker;
    $$self{download_url} = $download_url;

    my $callback = $req->param('callback');

    $$self{total_pages} = scalar @{ $self->pages };

    if ( -f $cache_filename ) {

        # requested with a callback; we have to generate a one-time
        # progress file to invoke the callback so it can present the right UI.
        # if we send data, the PDF is downloaded, but the client app
        # thinks something went awry.

        my $updater = new SRV::Utils::Progress
            download_url => $download_url,
            progress_filename => $progress_filename,
            total_pages => $$self{total_pages};

        $updater->finish;

        my $res = $req->new_response(200);
        $res->content_type($script_content_type);
        $res->body(qq{$callback('$progress_filename_url', '$download_url', $$self{total_pages});});
        return $res->finalize;

    }

    if ( $req->param('stop') ) {
        my $fh = new IO::File qq{$progress_filename.stop}, "w";
        $fh->close();
        my $res = $req->new_response(200);
        if ( $callback ) {
            $res->content_type($script_content_type);
            $res->body(qq{$callback('$progress_filename_url', '-', -1);});
        } else {
            $res->content_type('text/plain');
            $res->body('EOT');
        }
        return $res->finalize;
    }

    if ( -f qq{$progress_filename.stop} ) {
        # this would have been left over
        unlink qq{$progress_filename.stop};
    }

    # $progress_filename already exists
    # if it's less than 60 seconds, assume that the download has successfully
    # been launched in the background and tell the client to continue polling
    # $progress_filename
    if ( -f $progress_filename && ( time() - ((stat($progress_filename))[9]) < 60 ) ) {
        my $res = $req->new_response(200);
        $res->content_type($script_content_type);
        $res->body(qq{$callback('$progress_filename_url', '$download_url', $$self{total_pages});});
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
    push @cmd, "--progress_filename", $progress_filename;
    push @cmd, "--output_filename", $cache_filename;
    push @cmd, "--download_url", $$self{download_url};

    my $retval = SRV::Utils::run_command($env, \@cmd);

    my $res = $req->new_response(200);
    $res->content_type($script_content_type);
    my $body = [qq{$callback('$progress_filename_url', '$download_url', $$self{total_pages}, '$retval');}];
    push @$body, "\n", "@cmd";
    $res->body($body);
    return $res->finalize;

}

sub _stream {
    my ( $self, $env ) = @_;

    # return the file
    my $fh;
    my $cache_dir = SRV::Utils::get_cachedir();
    if ( $self->output_filename =~ m,^$cache_dir, ) {
        # make this a vanishing file
        $fh = new SRV::Utils::File $self->output_filename;
    } else {
        $fh = new IO::File $self->output_filename;
    }
    my $req = Plack::Request->new($env);
    my $res = $req->new_response(200);
    $res->content_type($content_type);
    $res->body($fh);

    # unlink the progress file
    unlink $self->progress_filename if ( defined $self->progress_filename );
    return $res->finalize;
}

sub run {
    my $self = shift;
    my $env = shift;
    my %args = @_;

    $self->_fill_params($env, \%args) if ( %args );
    $self->_validate_params();

    # calculate output_filename
    ### $self->_setup_output_filename($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    $self->restricted(0) unless ( Debug::DUtils::under_server() );

    # unless ( defined $self->restricted ) {
    #     my $restricted;
    #     $restricted = $C->get_object('Access::Rights')->assert_final_access_status($C, $gId) ne 'allow';
    #     unless ( $restricted || scalar @{ $self->pages } ) {
    #         # not restricted, and asking for full book
    #         my $full_book_restricted = $C->get_object('Access::Rights')->get_full_PDF_access_status($C, $gId);
    #         if ( $full_book_restricted ne 'allow' ) {
    #             # change the pages to the default sequence
    #             $self->pages([ $mdpItem->GetFirstPageSequence ]);
    #         }
    #     }
    #     $self->restricted($restricted);
    # }

    my $processor = Process::Article::PDF->new(
        mdpItem => $mdpItem,
        output_filename => $self->output_filename,
        progress_filename => $self->progress_filename,
        display_name => $self->display_name,
        institution => $self->institution,
        access_stmts => $self->access_stmts,
        proxy => $self->proxy,
        download_url => $self->download_url,
        marker => $self->marker,
        handle => $self->handle,
    );

    my $output = $processor->process($env);
    return $output;
}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    my $req = Plack::Request->new($env);
    my %params = (
        output_filename => undef,
        progress_filename => undef,
        # download_url => undef,
    );

    SRV::Utils::parse_env(\%params, [qw(output_filename progress_filename)], $req, $args);

    foreach my $param ( keys %params ) {
        $self->$param($params{$param});
    }

    $self->handle(SRV::Utils::get_itemhandle($mdpItem));

    # add user details
    my $auth = $C->get_object('Auth');
    $self->display_name($auth->get_user_display_name($C, 'unscoped'));
    $self->institution($auth->get_institution_name($C));
    $self->access_stmts(SRV::Utils::get_access_statements($mdpItem));
    $self->proxy($auth->get_PrintDisabledProxyUserSignature($C));

    $self->download_url($req->param('download_url')) if ( $req->param('download_url') );

    # if ( ! $self->output_filename && $ENV{PSGI_COMMAND} ) {
    #     # default to STDOUT
    #     $self->output_filename('-');
    # }

    my $marker = $req->param('marker');
    unless ( $marker ) {
        my $ses = $C->get_object('Session');
        if ( $ses ) {
            $marker = $ses->get_session_id();
        } else {
            $marker = ( $$ . time() );
        }
    }
    $self->marker($marker);

    my $cache_dir = SRV::Utils::get_cachedir();
    my $id = $mdpItem->GetId();

    unless ( $ENV{PSGI_COMMAND} ) {
        my $cache_filename = $self->output_filename;
        unless ( $cache_filename ) {
            $cache_filename = Identifier::id_to_mdp_path($id) . "__$marker" . ".pdf";
        }
        unless ( $cache_filename =~ m,^(\.\./|/), ) {
            $cache_filename = $cache_dir . $cache_filename;
        }
        Utils::mkdir_path( dirname($cache_filename), $SRV::Globals::gMakeDirOutputLog );
        $self->output_filename($cache_filename);

        my $progress_filename = $self->progress_filename;
        my $download_progress_cache_base = SRV::Utils::get_download_progress_base();
        unless ( $progress_filename ) {
            $progress_filename = Identifier::id_to_mdp_path($id) . "__" . $marker . ".html";
        }
        unless ( $progress_filename =~ m,^(\.\./|/), ) {
            $progress_filename = $download_progress_cache_base . $progress_filename;
        }
        Utils::mkdir_path( dirname($progress_filename), $SRV::Globals::gMakeDirOutputLog );
        $self->progress_filename($progress_filename);
    }



}

sub _validate_params {
    my ( $self ) = @_;

}

sub _get_alternate {
    my $self = shift;
    my $mdpItem = shift;
    my @fileids = $mdpItem->GetContent('article.alternate');
    if ( scalar @fileids ) { return $fileids[0]; }
    return undef;
}


1;

