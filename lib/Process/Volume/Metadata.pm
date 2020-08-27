package Process::Volume::Metadata;

use SRV::Utils;
use Process::Image;

use File::Slurp;

use Plack::Util::Accessor qw(
    mdpItem
    format
    start
    limit
    size
    target_width
);

use POSIX qw(ceil floor);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    $self->format('items') unless ( defined $self->format );

    $self;
}

sub process {
    my $self = shift;

    my $mdpItem = $self->mdpItem;
    my $retval = { 'start' => time(), 'errors' => {}, 'status' => 0 };
    $retval->{'first_page_sequence'} = $mdpItem->GetFirstPageSequence();

    $retval->{'download_progress_base'} = SRV::Utils::get_cachedir() . "progress/";
    $retval->{'download_progress_base'} =~ s,$ENV{SDRROOT},,;

    $retval->{'readingOrder'} = $mdpItem->Get('readingOrder');
    $retval->{'scanningOrder'} = $mdpItem->Get('scanningOrder');

    if ( $self->format eq 'items' ) {
        $retval->{'items'} = [];
    } else {
        $retval->{'width'} = [];
        $retval->{'page_num'} = [];
        $retval->{'seq'} = [];
        $retval->{'height'} = [];
        $retval->{'width'} = [];
        $retval->{'features'} = [];
        $retval->{'id'} = $mdpItem->GetId();
    }

    $self->_process_volume($retval);

    $retval->{finish} = time();
    $retval->{delta} = $retval->{finish} - $retval->{start};
    return $retval;    
}

sub _process_volume {
    my $self = shift;
    my ( $retval ) = @_;

    my $mdpItem = $self->mdpItem;
    my $id = $mdpItem->GetId();
    my $namespace = Identifier::the_namespace($id);
    my $stripped_id = Identifier::get_id_wo_namespace($id);

    my $format = $self->format;

    my $pageinfo_sequence = $mdpItem->Get('pageinfo')->{'sequence'};
    my @items = sort { int($a) <=> int($b) } keys %{ $pageinfo_sequence };

    $retval->{total_items} = scalar @items;

    my $start_idx = $self->start || 0;
    my $limit = ( defined $self->limit && $self->limit > 0 ) ? $self->limit : scalar @items;
    $limit = scalar @items if ( $limit > scalar @items );

    if ( defined $self->size ) {
        # convert size to px
        my $size = $self->size / 100;
        $size = floor($Process::Globals::default_width * $size);
        $self->target_width($size);
    }

    # # unpack everything
    my $status;

    ## find out how many bytes extracting all the images
    ## take; use to determine how many slices this will take

    my $total_bytes_extracted = 0; my $filenames = [];
    foreach my $seq ( @items[$start_idx .. $start_idx + $limit - 1] ) {
        next unless ( defined($seq) );
        my $filename = $mdpItem->GetFileNameBySequence($seq, 'imagefile');
        unless ( $filename ) { last; }
        push @$filenames, $filename;
        $total_bytes_extracted += $mdpItem->GetFileSizeBySequence($seq, 'imagefile');
    }

    my ( $use_width, $use_height, $type_or_error );
    my ( $use_filename, $filePath );

    # if we can, extract all the files and collect the image sizes
    $$retval{total_mb_extracted} = $total_bytes_extracted / 1024 / 1024;

    # find a non-landscape page, if possible
    my $tries = 0;
    my ( $use_width, $use_height );
    while ( ! $use_filename ) {
        my $seq = $items[int(rand(scalar @items))];
        next if ( grep(/MISSING_PAGE/, $mdpItem->GetPageFeatures($seq)) );
        $retval->{fudged_seq} = $seq;
        my $filename = $mdpItem->GetFilePathMaybeExtract($seq, 'imagefile');
        my ( $width, $height, $type_or_error ) = Process::Image::imgsize($filename);

        $tries += 1;

        if ( $width < $height && $height > 1024 || $tries > 1) {
            $use_filename = $filename;
            ( $use_width, $use_height ) = ( $width, $height );
        } else {
            unlink($filename);
        }

    }

    foreach my $seq ( @items[$start_idx .. $start_idx + $limit - 1] ) {
        next unless ( defined($seq) );

        my ( $width, $height );

        my $item = { 'seq' => int($seq) };
        $item->{'features'} = [ $mdpItem->GetPageFeatures($seq) ];

        if ( $use_filename ) {
            ( $width, $height ) = ( $use_width, $use_height );
            push @{$item->{features}}, 'FUDGED';
        } else {
            my $filename = $mdpItem->GetFileNameBySequence($seq, 'imagefile');
            ( $width, $height ) = Process::Image::imgsize(qq{$filePath/$filename});
            unlink(qq{$filePath/$filename});
        }

        $item->{width} = $width;
        $item->{height} = $height;

        unless(defined($width) && defined($height)) {
            $retval->{'errors'}->{$seq} = $type_or_error;
        }

        $self->_process_item($item, $retval);

    }
}

sub _process_item {
    my $self = shift;
    my ( $item, $retval ) = @_;

    my ( $r, $targetHeight, $outputRatio, $targetWidth );

    my $mdpItem = $self->mdpItem;

    $item->{page_num} = $mdpItem->GetPageNumBySequence($item->{seq});
    if ( $item->{'page_num'} ) {
        if ( $item->{'page_num'} =~ m!^\d+! ) {
            $item->{'page_num'} = int($item->{'page_num'})
        }
    };

    my ( $width, $height ) = ( $item->{width}, $item->{height} );
    if ( defined $self->size && defined($height) && defined($width) ) {
        my $r = $self->target_width / $width if ( $width > 0 );
        $targetWidth = $self->target_width;
        $targetHeight = int($height * $r);
    } else {
        $targetHeight = $height;
        $targetWidth = $width;
    }

    $item->{'id'} = $mdpItem->GetId();
    $item->{'height'} = $targetHeight;
    $item->{'width'} = $targetWidth;

    # if ( $height == $width == 1 ) {
    #     $item->{height} = $item->{width} = 1;
    # }

    if ( defined $self->size ) {
        $item->{'size'} = $size;
    }

    if ( $self->format eq 'items' ) {
        push @{ $retval->{'items'} }, $item;
    } else {
        foreach my $key (qw(width height seq page_num features)) {
            push @{$retval->{$key}}, $item->{$key};
        }
    }    
}


1;