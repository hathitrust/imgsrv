package PDF::API2::Resource::XObject::Image::JPEG2000;

our $VERSION = '1.12'; # VERSION

use base 'PDF::API2::Resource::XObject::Image';

use IO::File;
use PDF::API2::Util;
use PDF::API2::Basic::PDF::Utils;

use Image::ExifTool qw(:Public);

no warnings qw[ deprecated recursion uninitialized ];

sub new
{
    my ($class,$pdf,$file,$name) = @_;
    my $self;
    ### my $fh = IO::File->new;

    $class = ref $class if ref $class;

    $self=$class->SUPER::new($pdf,$name|| 'Jx'.pdfkey());
    $pdf->new_obj($self) unless($self->is_obj($pdf));

    $self->{' apipdf'}=$pdf;

    my $info = ImageInfo($file);
    my @stat = stat($file);
    $self->{Length} = PDFNum($stat[7]);
    $self->{' streamfile'} = $file;
    # Colorspace (lowercase "s") == JPEG2000 tag
    # ColorSpace (uppercaes "s") == XMP tag
    my $colorspace = $$info{Colorspace} || $$info{ColorSpace};
    if ( $ENV{__debug_jpeg2000_exif} ) {
        $colorspace = $$info{ColorSpace} || $$info{Colorspace};
    }

    if ( $colorspace eq 'sRGB' ) {
        $self->colorspace('DeviceRGB')
    } elsif ( $colorspace eq 'Grayscale' ) {
        $self->colorspace('DeviceGray')
    } else {
        print STDERR "Unknown colorspace: ", $colorspace, "\n";
        $self->colorspace('DeviceRGB');
    }

    $self->height($info->{ImageHeight});
    $self->width($info->{ImageWidth});
    $self->bpc(8); # $info->{BitsPerComponent} is text

    $self->filters('JPXDecode');
    $self->{' nofilt'}=1;

    return($self);
}

=item $res = PDF::API3::Compat::API2::Resource::XObject::Image::JPEG->new_api $api, $file [, $name]

Returns a jpeg-image object. This method is different from 'new' that
it needs an PDF::API3::Compat::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $obj->{' api'}=$api;

    return($obj);
}

1;
