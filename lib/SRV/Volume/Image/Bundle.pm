package SRV::Volume::Image::Bundle;

use strict;
use warnings;

use parent qw( SRV::Volume::Base );

use Plack::Request;
use Plack::Response;
use Plack::Util;

use Plack::Util::Accessor
    @SRV::Volume::Base::accessors,
    qw(
        rotation
        target_ppi
        quality
        max_dim
    );

use Utils;

use SRV::Globals;
use SRV::Utils;

use Data::Dumper;

use IO::File;

use File::Basename qw(basename dirname fileparse);
use File::Path qw(remove_tree);
use File::Temp qw(tempfile);
use POSIX qw(strftime);
use Time::HiRes;

use Digest::SHA qw(sha256_hex);

use utf8;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->format('image/jpg') unless ( defined $self->format );
    $self->bundle_format('zip') unless ( defined $self->bundle_format );
    
    $self;
}

sub _run {
    my $self = shift;
    my $env = shift;
    my $updater = shift;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    my $class = q{Process::Volume::Image::Bundle};

    # print STDERR join(" / ", "AHOY BUNDLE", $self->bundle_format, $self->handle, $self->format, $self->target_ppi), "\n";

    $class = Plack::Util::load_class($class);
    my $process = $class->new(
        mdpItem => $mdpItem,
        output_filename => $self->output_filename,
        progress_filepath => $self->progress_filepath,
        cache_dir => SRV::Utils::get_cachedir(),
        display_name => $self->display_name,
        institution => $self->institution,
        access_stmts => $self->access_stmts,
        restricted => $self->restricted,
        proxy => $self->proxy,
        download_url => $self->download_url,
        handle => $self->handle,       
        limit => $self->limit,
        watermark => $self->watermark,
        bundle_format => $self->bundle_format,
        format => $self->format,
        target_ppi => $self->target_ppi,
        quality => $self->quality,
        pages => $self->pages,
        is_partial => $self->is_partial,
        updater => $updater,
    );
    $process->process($env);
}

sub _authorize {
    my $self = shift;
    my $env = shift;

    $self->SUPER::_authorize($env);
    unless ( $self->restricted ) {
        # technically the user has access but we need to 
        # limit resources for bundling to users in a current session
        # unless you're using XYZZY=1 on the command line
        my $C = $$env{'psgix.context'};
        my $ses = $C->get_object('Session');
        if ( $$ses{is_new} && ! $ENV{XYZZY} ) { $self->restricted(1); }
        elsif ( $self->format eq 'image/tiff' && $self->total_pages > 10 ) {
            $self->restricted(1);
        }
    }
}

sub _possible_params {
    my $self = shift;

    my %params = $self->_default_params;
    $params{rotation} = '0';
    $params{target_ppi} = undef;
    $params{quality} = 'default';
    $params{bundle_format} = 'zip';
    $params{format} = 'image/jpeg';

    return %params;
}

sub _content_type {
    my $self = shift;
    return ( $self->bundle_format eq 'zip' ? 'application/zip' : 'text/plain' );
}

sub _type {
    my $self = shift;
    return 'ZIP archive';
}

sub _action {
    my $self = shift;
    return q{image};
}

sub _ext {
    my $self = shift;
    return 'zip';
}

sub _updater {
    my $self = shift;
    my %params = @_;
    return new SRV::Utils::Progress
        type => 'zip archive',
        %params;
}

sub _download_params {
    my $self = shift;
    return ( 
        [ 'format', $self->format ],
        [ 'target_ppi', $self->target_ppi ],
        [ 'bundle_format', $self->bundle_format ],
    );
}

sub get_restricted_message {
    my $self = shift;
    my ( $env ) = @_;
    if ( $self->format eq 'image/tiff' && $self->total_pages > 10 ) {
        return qq{<html><body>Packaging of TIFF images is currently limited to 10 page scans.</body></html>};
    }
    return qq{<html><body>Restricted</body></html>};
}


1;
