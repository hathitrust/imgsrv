package Process::PDF;

use strict;
use warnings;
use IPC::Run;
use File::Basename qw(dirname basename fileparse);
use Time::HiRes;

use File::Slurp qw(write_file);
use JSON::XS qw(encode_json);

use Plack::Util::Accessor qw(
    output_filename
    output_document
    cache_dir
    mdpItem
    marker
    restricted
    limit
    pages
    total_pages
    is_partial
    updater
    stamper
);

sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;


    $self;
}

sub process {
    my $self = shift;
    my $env = shift;

    # NEED TO EXTRACT MY PDF
    my $mdpItem = $self->mdpItem;
    my $hash = $mdpItem->GetFileGroupMap;
    my $fileid;
    foreach my $key ( keys %$hash ) {
        if ( $$hash{$key}{mimetype} eq 'application/pdf' ) {
            $fileid = $key; # $$hash{$key};
            last;
        }
    }

    # this would be an error if we can't find the PDF
    # and should probably punt to the standard PDF process. Hm.

    my $input_filename = $mdpItem->GetFilePathMaybeExtract($fileid, 'pdffile');
    my $stamper_filename = $self->stamper->output_filename;
    # this part is stupid --- but stamper is already unique for this session
    my $output_filename = ref($self->output_filename) ? $stamper_filename . "__output.pdf" : $self->output_filename;

    my $config = {};
    $$config{input_filename} = $input_filename;
    $$config{stamper_filename} = $stamper_filename;
    $$config{output_filename} = $output_filename;
    $$config{pages} = undef;
    if ( $self->is_partial ) {
        $$config{pages} = [];
        foreach my $seq ( @{ $self->pages } ) {
            push @$config{pages}, int($seq);
        }
    }

    if ( $self->updater ) {
        $$config{update_filepath} = $self->updater->filepath;
        $$config{download_url} = $self->updater->download_url;
    }

    my $config_filename = $stamper_filename . "__config.js";
    write_file($config_filename, encode_json($config));

    IPC::Run::run [ "$ENV{SDRROOT}/imgsrv-tools/scripts/stamp_pdf.pl", 
            "--config_filename", $config_filename ];

    unlink $config_filename;

    if ( ref($self->output_filename) ) {
        # $self->output_filename(SRV::Utils::File->new($output_filename));
        # my $fh = SRV::Utils::File->new($output_filename);
        open my $fh, $output_filename || die "could not open $output_filename - $!";
        while ( <$fh> ) {
            $self->output_filename->print($_);
        }
        unlink $output_filename;
    }

    return 1;

}


1;