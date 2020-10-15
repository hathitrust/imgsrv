package Package::Text::Volume;

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
    files
);

use Process::Globals;

use SRV::Utils;
use SRV::Globals;

use Data::Dumper;
use IO::File;

use File::Temp qw(tempdir);

use POSIX qw(strftime);

use ISO639;

use File::Basename qw(basename dirname fileparse);
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Slurp qw();
use Data::Dumper;
use List::MoreUtils qw(any);
use POSIX qw(strftime);
use Time::HiRes;

our $WHICH_TO_EXT_MAP = {};
$$WHICH_TO_EXT_MAP{ocrfile} = 'txt';

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

    die "TEXT BUNDLE CANCELLED" if ( $updater->is_cancelled );

    $updater->update(0);

    $self->build_content();

    die "TEXT BUNDLE CANCELLED" if ( $updater->is_cancelled );

    $updater->finish();

    return 1;

}

sub build_content {
    my $self = shift;

    my $updater = $self->updater;
    my $mdpItem = $self->mdpItem;

    $self->files({});

    unless ( $self->is_partial ) {
        return $self->process_all_pages();
    }

    my $i = 0;
    foreach my $seq ( @{ $self->pages } ) {

        die "TEXT BUNDLE CANCELLED" if ( $updater->is_cancelled );

        $i += 1;
        $updater->update($i);

        $self->process_page_text($seq);
    }
}

sub additional_message {
    my $self = shift;
    return 
        "This file has been created from the computer-extracted text of scanned page images. Computer-extracted text may have errors, such as misspellings, unusual characters, odd spacing and line breaks."
    ;
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

sub process_page_text {
    my $self = shift;
    my ( $seq) = @_;

    my $extract_filename = $self->mdpItem->GetFilePathMaybeExtract($seq, 'ocrfile');
    my $target_filename = $self->add_file($seq, 'ocrfile');

    copy($extract_filename, $self->pathname($target_filename)) || die $!;
}

sub process_all_pages {
    my $self = shift;

    $self->updater->update(0);
    my $i = 0;

    my $extract_pathname = $self->mdpItem->GetDirPathMaybeExtract(['*/*.txt']);

    foreach my $seq ( @{ $self->pages } ) {
        my $extract_filename = $self->mdpItem->GetFileNameBySequence($seq, 'ocrfile');

        my $target_filename = $self->add_file($seq, 'ocrfile');
        copy("$extract_pathname/$extract_filename", $self->pathname($target_filename));

        $i += 1;
        $self->updater->update($i);
    }

}

sub add_file {
    my $self = shift;
    my ( $seq, $which ) = @_;
    my $basename = sprintf("%08d", $seq);
    my $ext = $$WHICH_TO_EXT_MAP{$which};

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