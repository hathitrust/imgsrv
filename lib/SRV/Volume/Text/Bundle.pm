package SRV::Volume::Text::Bundle;

use strict;
use warnings;

use parent qw( SRV::Volume::Base );

use Plack::Request;
use Plack::Response;
use Plack::Util;

use Plack::Util::Accessor
    @SRV::Volume::Base::accessors;

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
    
    $self;
}

sub _run {
    my $self = shift;
    my $env = shift;
    my $updater = shift;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    my $class = q{Process::Volume::Text::Bundle};

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
        format => $self->format,
        pages => $self->pages,
        is_partial => $self->is_partial,
        updater => $updater,
    );
    $process->process($env);
}

sub _possible_params {
    my $self = shift;
    return $self->_default_params;
}

sub _content_type {
    my $self = shift;
    return ( $self->format eq 'zip' ? 'application/zip' : 'text/plain' );
}

sub _type {
    my $self = shift;
    return ( $self->format eq 'zip' ? 'ZIP archive' : 'concatenated text file' );
}

sub _action {
    my $self = shift;
    return q{pdf};
}

sub _ext {
    my $self = shift;
    return ( $self->format eq 'zip' ? 'zip' : 'txt' );
}

sub _updater {
    my $self = shift;
    my %params = @_;
    return new SRV::Utils::Progress
        type => ( $self->format eq 'zip' ? 'zip archive' : 'combined text file' ),
        %params;
}

1;
