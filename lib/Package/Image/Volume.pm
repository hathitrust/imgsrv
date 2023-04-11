package Package::Image::Volume;

use strict;
use warnings;

use parent qw( Plack::Component );

use Plack::Util;
use Plack::Util::Accessor qw(
    access_stmts 
    display_name 
    institution 
    proxy 
    handle 
    output_filename 
    progress_filepath 
    cache_dir
    download_url
    marker
    restricted 
    watermark 
    id
    updater
    working_dir
    layout
    mdpItem
    auth
    pages
    is_partial
    format
    target_ppi
    size
    files
    quality
);

use Process::Globals;

use SRV::Utils;
use SRV::Globals;

use Data::Dumper;
use IO::File;

use File::Temp qw(tempdir);

use POSIX qw(strftime);

use Process::Image;

use File::Basename qw(basename dirname fileparse);
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Slurp qw();
use Data::Dumper;
use List::MoreUtils qw(any);
use POSIX qw(strftime);
use Time::HiRes;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    $self;
}

sub generate {
    my $self = shift;
    my ( $env ) = @_;

    my $mdpItem = $self->mdpItem;
    my $auth = $self->auth;

    my $updater = $self->updater;

    $$self{readingOrder} = $mdpItem->Get('readingOrder');

    die "IMAGE BUNDLE CANCELLED" if ( $updater->is_cancelled );

    $updater->update(0);

    $self->build_content($env);

    die "IMAGE BUNDLE CANCELLED" if ( $updater->is_cancelled );

    return 1;

}

sub build_content {
    my $self = shift;
    my ( $env ) = @_;

    my $updater = $self->updater;
    my $mdpItem = $self->mdpItem;

    $self->files({});

    if ( ! defined $self->target_ppi ) { $self->size(qq{ppi:75}); }
    elsif ( defined $self->target_ppi && $self->target_ppi == 0 ) {
        $self->size('full');
    } else {
        $self->size(q{ppi:} . $self->target_ppi);
    }

    my $i = 0;
    foreach my $seq ( @{ $self->pages } ) {

        die "IMAGE BUNDLE CANCELLED" if ( $updater->is_cancelled );

        $i += 1;
        $updater->update($i);

        $self->process_page_image($env, $seq);
    }

    unlink $self->working_dir . "/process.log";
}

sub get_page_basename {
    my $self = shift;
    my ( $seq ) = @_;
    unless ( ref($$self{basenames}) ) { $$self{basenames} = {}; }
    unless ( $$self{basenames}{$seq} ) {
        # my $ocr_filename = $self->mdpItem->GetFileNameBySequence($seq, 'ocrfile');
        # $$self{basenames}{$seq} = basename($ocr_filename, ".txt");
        $$self{basenames}{$seq} = sprintf("%08d", $seq);
    }
    return $$self{basenames}{$seq};
}

sub process_page_image {
    my $self = shift;
    my ( $env, $seq) = @_;

    my $extract_filename = $self->mdpItem->GetFilePathMaybeExtract($seq, 'imagefile');

    my $target_ext = $self->format eq 'image/tiff' ? 'tif' : 'jpg';
    my $target_filename = $self->working_dir . "/" . $self->add_file($seq, $target_ext);

    my $blank = 0;
    my @features = $self->mdpItem->GetPageFeatures($seq);
    if ( grep(/CHECKOUT_PAGE/, @features) ) {
        # this should be a blank page
        $blank = 1;
    }

    my $processor = new Process::Image;

    $processor->mdpItem($self->mdpItem);
    $processor->source( filename => $extract_filename);
    $processor->output( filename => $target_filename );
    $processor->format($self->format);
    $processor->size($self->size);
    # $processor->region($self->region);
    # $processor->rotation($self->rotation);
    $processor->logfile($self->working_dir . "/process.log");
    $processor->watermark($self->watermark);
    $processor->restricted($self->restricted);
    # $processor->max_dim($max_dimension) if ( $max_dimension );
    $processor->quality($self->quality);
    $processor->blank($blank) if ( $blank );
    $processor->transformers( $$env{'psgix.image.transformers'} ) if ( defined $$env{'psgix.image.transformers'} );

    $processor->process();
}

sub add_file {
    my $self = shift;
    my ( $seq, $which ) = @_;
    my $basename = sprintf("%08d", $seq);
    my $ext = $which;

    $self->files->{$seq} = {} unless ( ref($self->files->{$seq}) );
    $self->files->{$seq}->{$which} = "$basename.$ext";

    return "$basename.$ext";
}

sub get_file {
    my $self = shift;
    my ( $seq, $which ) = @_;

    return $self->files->{$seq}->{$which};
}

sub pathname {
    my $self = shift;
    my ( $pathname ) = @_;

    return join('/', $self->working_dir, $pathname);
}

1;
