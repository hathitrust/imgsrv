package SRV::Volume::PDF;
use strict;
use warnings;

use parent qw( SRV::Volume::Base );

use Plack::Request;
use Plack::Response;
use Plack::Util;

use Plack::Util::Accessor
    @SRV::Volume::Base::accessors,
    qw(
        searchable
        rotation
        target_ppi
        quality
        max_dim
        stamp_filename
    );

use Utils;
use Debug::DUtils;

use SRV::Globals;
use SRV::Utils;

use Data::Dumper;

use IO::File;

use File::Basename qw(basename dirname fileparse);
use File::Path qw(remove_tree);
use POSIX qw(strftime);
use Time::HiRes;

use Digest::SHA qw(sha256_hex);

use Process::Watermark::PDF;

use utf8;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->target_ppi(0) unless ( defined $self->target_ppi );
    $self->rotation(0) unless ( defined $self->rotation );
    $self->searchable(1) unless ( defined $self->searchable );
    $self->quality('default') unless ( defined $self->quality );

    $self;
}

sub _generate_coderef {
    my $self = shift;
    my $env = shift;

    return sub {
        my $responder = shift;

        my $status = ( Debug::DUtils::under_server() && $self->restricted ) ? 403 : 200;

        my $headers = $self->_get_response_headers;

        if ( $self->tracker ) {
            my $req = Plack::Request->new($env);
            my $value = $req->cookies->{tracker} || '';
            $value .= $self->tracker;
            my $expires = strftime("%a, %d-%b-%Y %H:%M:%S GMT", gmtime(time + 24 * 60 * 60));
            push @$headers, 
                'Set-Cookie',
                qq{tracker=$value; path=/; expires=$expires};
        }


        my $writer = $responder->([$status, $headers]);
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

sub _run {
    my $self = shift;
    my $env = shift;
    my ( $updater ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

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
    my $self = shift;
    my $env = shift;

    $self->SUPER::_fill_params($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    # the stamp filename has to be distinct from the working directory set up when you have a $marker
    # because streaming does not create a $marker
    my $stamp_filename = SRV::Utils::get_cachedir('download_cache_dir') . sha256_hex($self->user_volume_identifier) . time() . '__stamp.pdf';
    Utils::mkdir_path( dirname($stamp_filename), $SRV::Globals::gMakeDirOutputLog );
    $self->stamp_filename($stamp_filename);

    $self->max_dim(SRV::Utils::get_max_dimension($mdpItem));
}

sub _possible_params {
    my $self = shift;

    my %params = $self->_default_params;
    $params{rotation} = '0';
    $params{target_ppi} = undef;
    $params{quality} = 'default';

    return %params;
}

sub _content_type {
    my $self = shift;
    return q{application/pdf};
}

sub _type {
    my $self = shift;
    return q{PDF};
}

sub _action {
    my $self = shift;
    return q{pdf};
}

sub _ext {
    my $self = shift;
    return q{pdf};
}

1;
