package Image::Utils;

use Image::Info;
use Image::Info::_patches;
use POSIX qw(ceil);

sub image_info {
    # this is dumb
    if ( 0 && $INC{'Image/ExifTool.pm'} ) {
        my $retval = Image::ExifTool::ImageInfo(@_);
        $$retval{width} = $$retval{ImageWidth};
        $$retval{height} = $$retval{ImageHeight};
        return $retval;
    }
    my $retval = Image::Info::image_info(@_);
    $$retval{FileName} = $_[0];
    return $retval;
}

sub page_dim {
    local($info) = @_;

    my $meta = _normalize($info);
    my ( $page_width, $page_height );
    $page_width = ceil(( $$meta{width} / $$meta{dpi} ) * 72);
    $page_height = ceil(( $$meta{height} / $$meta{dpi} ) * 72);

    return ( $page_width, $page_height );
}

sub resize {
    local($info, $resolution) = @_;
    my $meta = _normalize($info);
    my $unit = 'dpi';

    if ( $unit eq 'dpi' ) {
        my $ratio = $resolution / $$meta{dpi};
        $ratio = 1 if ( $ratio > 1 );
        print STDERR "AHOY WUT $$meta{width} x $$meta{height} :: $resolution / $$meta{dpi} :: $ratio :: $$meta{XResolution} :: $$meta{dpi}\n";
        $$meta{width} = ceil($$meta{width} * $ratio);
        $$meta{height} = ceil($$meta{height} * $ratio);
        $$meta{XResolution} = $$meta{YResolution} = $resolution;
        $$meta{ResolutionUnit} = 'dpi';

    }

    return $meta;
}

sub _normalize {
    local ( $info ) = @_;
    my $meta = { %$info };
    $$meta{height} = $$info{height} || $$info{ImageHeight};
    $$meta{width} = $$info{width} || $$info{ImageWidth};

    my $resolution = $$info{XResolution};
    if ( ref($resolution) ) {
        $resolution = $resolution->as_float;
    } elsif ( ! $resolution ) {
        $resolution = $$info{FileName} =~ m,\.jp2, ? 400 : 600;
    }

    # normalize the resolution to dpi
    my $unit = $$info{ResolutionUnit};
    my $dpi;
    if ( $unit eq '0.01 mm' ) {
        $dpi = ceil( ( $resolution * 0.1 ) / 2.54 * ( 1 / 0.01 * 100 ) );
    } elsif ( $unit eq '0.1 mm' ) {
        $dpi = ceil( ( $resolution * 0.1 ) * 2.54 * ( 1 / 0.1 * 100 ) );
    } elsif ( $unit eq '10 m' ) {
        $dpi = ceil( ( $resolution * 0.0254 ) / 10 );
    } elsif ( $unit eq 'dpcm' ) {
        $dpi = $resolution * 2.54;
    } elsif ( $unit eq 'inches' ) {
        $dpi = $resolution;
    } elsif ( $unit eq 'um' ) {
        $dpi = $resolution * 10**6 * 0.0254;
    } elsif ( $unit eq 'dpi' || ( $resolution =~ m,\d{3}, ) ) {
        $dpi = $resolution;
    } else {
        # what should this dpi be?
        $dpi = 600;     
    }

    $$meta{dpi} = $$meta{XResolution} = $$meta{YResolution} = $dpi;
    $$meta{ResolutionUnit} = 'dpi';
    return $meta;

}


1;