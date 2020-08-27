package SRV::Volume::Metadata;

use strict;
use warnings;

use parent qw( Plack::Component );

use Plack::Request;
use Plack::Response;
use Plack::Util;
use Plack::Util::Accessor qw( 
    format
    size
    start
    limit
);

use Identifier;
use Utils;
use Utils::Cache::JSON;
use Debug::DUtils;

use SRV::Globals;
use SRV::Utils;

use Data::Dumper;

use IO::File;
use File::Slurp qw(read_file);

use File::Basename qw(basename dirname fileparse);
use File::Path qw(remove_tree);
use POSIX qw(strftime);
use Time::HiRes;

use Process::Volume::Metadata;

use utf8;

our $debug_content_type = 'text/plain';
our $content_type = 'application/javascript';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->format('items') unless ( defined $self->format );

    $self;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    $self->_fill_params($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $id = $mdpItem->GetId();

    my $cache = Utils::Cache::JSON->new(SRV::Utils::get_cachedir(), undef, $mdpItem->get_modtime());
    my $key = $self->_key($req, $id);
    my $output_filename = $cache->GetFile($id, $key);

    if ( ! defined $output_filename || ! -f $output_filename || ! -e $output_filename || $req->param('force') ) {
        my $processor = Process::Volume::Metadata->new(
            mdpItem => $mdpItem,
            format  => $self->format,
            start => $self->start,
            limit => $self->limit,
            size => $self->size,
        );
        my $metadata = $processor->process();
        $output_filename = $cache->Set($id, $key, $metadata);
    }

    my $res = $req->new_response(200);
    $res->content_type(($req->param('debug') ? $debug_content_type : $content_type ) . ';charset=utf-8');
    
    if ( $req->param('callback') ) {
        my $data = read_file($output_filename);
        $res->body($req->param('callback') . '(' . $data . ')');
    } else {
        my $fh = new IO::File $output_filename;
        $res->body($fh);
    }

    return $res->finalize;

}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    my $req = Plack::Request->new($env);
    my %params = (
        format => $self->format,
        size => $SRV::Globals::gDefaultSize,
    );

    SRV::Utils::parse_env(\%params, [qw(size format)], $req, $args);

    foreach my $param ( keys %params ) {
        $self->$param($params{$param});
    }
}

sub _validate_params {
    my ( $self ) = @_;

}

sub _key {
    my $self = shift;
    my ( $req, $id ) = @_;
    my @parts = ( 'metadata' );
    push @parts, ( $req->param('start') || '0');
    push @parts, ( $req->param('limit') || '0');
    push @parts, ( $req->param('format') || $self->format );
    return join('_', @parts);
}

1;
