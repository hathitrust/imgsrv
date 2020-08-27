#!/usr/bin/env perl


package Image::Sizer;

use Data::Dumper;
use strict;
use IO::File;
require Exporter;

use Image::Size qw();

our(@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION, $DEBUG);
$DEBUG = 0;

BEGIN
{
    @ISA = qw(Exporter);
    @EXPORT = qw(imgsize imginfo);
    @EXPORT_OK = qw(imgsize imginfo);
    %EXPORT_TAGS = ('all' => [ @EXPORT ]);
    $VERSION = "0.001";
    $VERSION = eval $VERSION;
}

sub imgsize {
    my ( $filename ) = @_;
    my ( $w, $h, $retval );
    if ( $filename =~ m!\.jp2$! ) {
        my $info;
        ($info, $retval) = jp2info($filename);
        if(ref($info)) {
            print STDERR Dumper($info), "\n" if ( $DEBUG );
            ( $w, $h) = ( $info->{'width'}, $info->{'height'} );
            $retval = 'JP2';
        }
    } else {
        ( $w, $h, $retval ) = Image::Size::imgsize($filename);
    }
    $w = int($w) if defined($w);
    $h = int($h) if defined($h);
    return ( $w, $h, $retval );
}

sub imginfo {
    my ( $filename ) = @_;
    if ( $filename =~ m!\.jp2! ) {
        return jp2info($filename);
    } else {
        my $module = "Image::ExifTool";
        my $method = "Image::ExifTool::ImageInfo";
        eval "require $module";
        return &$method($filename);
    }
}

sub _dump {
    my ( $s ) = @_;
    my $idx = 0;
    my @retval = ();
    foreach my $ch ( split(//, $s) ) {
        push @retval, uc sprintf("%02x", (ord($ch)));
    }
    return join(" ", @retval);
}

sub _read8 {
    my ( $fh ) = @_;
    my $data;
    $fh->read($data, 8);
    my @bits = split(//, $data);
    my $retval =  
        (ord($bits[0]) << 52) + 
        (ord($bits[1]) << 48) + 
        (ord($bits[2]) << 40) + 
        (ord($bits[3]) << 32) + 
        (ord($bits[4]) << 24) + 
        (ord($bits[5]) << 16) + 
        (ord($bits[6]) << 8) + 
        ord($bits[7]);
    return $retval;
}

sub _read4 {
    my ( $fh ) = @_;
    my $data;
    $fh->read($data, 4);
    my @bits = split(//, $data);
    my $retval = (ord($bits[0]) << 24) + (ord($bits[1]) << 16) + (ord($bits[2]) << 8) + ord($bits[3]);
    return $retval;
}

sub _read2 {
    my ( $fh ) = @_;
    my $data;
    $fh->read($data, 2);
    my @bits = split(//, $data);
    my $retval = (ord($bits[2]) << 8) + ord($bits[3]);
    return $retval;
}

sub _read1 {
    my ( $fh ) = @_;
    my $data;
    $fh->read($data, 1);
    my @bits = split(//, $data);
    my $retval = ord($bits[3]);
    return $retval;
}

use constant JP2_BOX_ID => join('', chr(0x6a), chr(0x70), chr(0x32), chr(0x63));
use constant JP2_COLR_ID => join('', chr(0x63), chr(0x6f), chr(0x6c), chr(0x72));
use constant JP2_HEADER_ID => join('', chr(0x6a), chr(0x70), chr(0x32), chr(0x68));
use constant JP2_UUID_ID => join('', chr(0x75), chr(0x75), chr(0x69), chr(0x64));

use constant JPEG2000_MARKER_PREFIX => 0xFF ; # /* All marker codes start with this */
use constant JPEG2000_MARKER_SOC => 0x4F ; # /* Start of Codestream */
use constant JPEG2000_MARKER_SOT => 0x90 ; # /* Start of Tile part */
use constant JPEG2000_MARKER_SOD => 0x93 ; # /* Start of Data */
use constant JPEG2000_MARKER_EOC => 0xD9 ; # /* End of Codestream */
use constant JPEG2000_MARKER_SIZ => 0x51 ; # /* Image and tile size */
use constant JPEG2000_MARKER_COD => 0x52 ; # /* Coding style default */ 
use constant JPEG2000_MARKER_COC => 0x53 ; # /* Coding style component */
use constant JPEG2000_MARKER_RGN => 0x5E ; # /* Region of interest */
use constant JPEG2000_MARKER_QCD => 0x5C ; # /* Quantization default */
use constant JPEG2000_MARKER_QCC => 0x5D ; # /* Quantization component */
use constant JPEG2000_MARKER_POC => 0x5F ; # /* Progression order change */
use constant JPEG2000_MARKER_TLM => 0x55 ; # /* Tile-part lengths */
use constant JPEG2000_MARKER_PLM => 0x57 ; # /* Packet length, main header */
use constant JPEG2000_MARKER_PLT => 0x58 ; # /* Packet length, tile-part header */
use constant JPEG2000_MARKER_PPM => 0x60 ; # /* Packed packet headers, main header */
use constant JPEG2000_MARKER_PPT => 0x61 ; # /* Packed packet headers, tile part header */
use constant JPEG2000_MARKER_SOP => 0x91 ; # /* Start of packet */
use constant JPEG2000_MARKER_EPH => 0x92 ; # /* End of packet header */
use constant JPEG2000_MARKER_CRG => 0x63 ; # /* Component registration */
use constant JPEG2000_MARKER_COM => 0x64 ; # /* Comment */

sub jp2info {
    my ( $filename ) = @_;
    my $img = IO::File->new($filename) || return (undef, "Can't open image file $filename : $!");

    my $buffer;
    my $box_type;
    my $box_length;
    
    my ( $dummy_short, $dummy_byte );
    
    my $result = {};

    my $n = 0;
    my $skip_seek = 0;
    while(1) {
        $box_length = _read4($img);

        unless($img->read($box_type, 4) == 4) {
            last;
        }

        if(length($box_type) != 4) {
            last;
        }

        print STDERR _dump($box_type), " / ", _dump(JP2_HEADER_ID), " / ", _dump(JP2_BOX_ID), "\n" if ( $DEBUG );
        
        my $offset = 8;

        if(substr($box_type, 0, 4) eq substr(JP2_HEADER_ID, 0, 4)) {
            ### $skip_seek = 1;
            my $pos = $img->tell();
            my ($inner_box_length, $inner_box_type, $inner_offset);
            while($img->tell() <= ( $pos + $box_length )) {
                $inner_box_length = _read4($img);
                if ( $inner_box_length <= 0) {
                    ### print "= inner: ending = $inner_box_length\n";
                    $offset += 5;
                    last;
                }
                $img->read($inner_box_type, 4);
                $offset += 8;
                $inner_offset = 8;
                if ( substr($inner_box_type, 0, 4) eq substr(JP2_COLR_ID, 0, 4)) {
                    # my $m = _read2($img);
                    my $m = $img->getc;
                    $inner_offset += 1;
                    $dummy_byte = $img->getc; $inner_offset += 1; # P
                    $dummy_byte = $img->getc; $inner_offset += 1; # A
                    if ( $m eq chr(1) ) {
                        my $ecs = _read4($img); $inner_offset += 4;
                        if ( $ecs == 17 ) {
                            $result->{'colorspace'} = 'Grayscale';
                        } elsif ( $ecs == 16 ) {
                            $result->{'colorspace'} = 'sRGB';
                        } elsif ( $ecs == 18 ) {
                            $result->{'colorspace'} = 'sYCC';
                        }
                    } elsif ( $m eq chr(2) ) {
                        # beyond our scope
                    }
                }
                $img->seek($inner_box_length - $inner_offset, 1);
            }
            $img->seek($pos, 0); # some box types are beyond the header box??
            $offset = 8;
        }

        if(substr($box_type, 0, 4) eq substr(JP2_BOX_ID, 0, 4)) {
            $img->seek(3, 1);
            my $first_marker_id = $img->getc;
            if ( $first_marker_id != chr(JPEG2000_MARKER_SIZ) ) {
                _dump($first_marker_id);
                exit;
            }

            # my $result = {};

            $dummy_short = _read2($img); # Lsiz
            $dummy_short = _read2($img); # Rsiz

            $result->{width} = _read4($img);
            $result->{height} = _read4($img);

            $img->seek(24, 1);

            $result->{channels} = _read2($img);
            if ( $result->{channels} < 0 || $result->{channels} > 256 ) {
                # BOGUS
                print STDERR "RETURN: BAD CHANNELS :: ", $result->{channels}, "\n" if ( $DEBUG );
                return;
            }

            my $highest_bit_depth = 0;
            foreach my $i ( 0 .. $result->{channels} ) {
                my $bit_depth = ord($img->getc);
                $bit_depth += 1;
                if ( $bit_depth > $highest_bit_depth ) {
                    $highest_bit_depth = $bit_depth;
                }

                my $xrsiz = $img->getc();
                my $yrsiz = $img->getc();

            }

            $result->{bits} = $highest_bit_depth;
            
            # technically, we do NOT care about any data after this code block
            $img->close;
            print STDERR "RETURN: DONE READING DATA #1", "\n" if ( $DEBUG );
            return $result;
            
        }
        
        if(substr($box_type, 0, 4) eq substr(JP2_UUID_ID, 0, 4)) {
            my $check;
            my $uuid;
            my $inner_box_length;
            if ( $box_length == 1 ) {
                # we are a HUGE box
                $inner_box_length = _read8($img);
                print STDERR "KNOW LENGTH: $inner_box_length\n" if ( $DEBUG );
                $img->read($uuid, 16);
                $img->seek($inner_box_length - 16 - 4 - 8 - 4, 1);
            } else {
                print STDERR "DO NOT KNOW LENGTH\n" if ( $DEBUG );
                $img->read($uuid, 16);
                $img->seek($box_length - 16 - 4 - 4, 1);
                
                $box_length = 1;

                # don't know the length, so keep reading until you
                # hit another JP2 marker

            }
            print STDERR "UUID: ", _dump($uuid), " / ", $inner_box_length, "\n" if ( $DEBUG );
            $offset = 1;
            # $box_length = 16; # UUID bytes
        }

        if ( $box_length <= 0 ) {
            print STDERR "ENDING: $box_length < 0\n" if ( $DEBUG );
            last;
        }
        
        unless($img->seek($box_length - $offset, 1)) {
            print STDERR "ENDING: $box_length - $offset :: ", ($box_length - $offset), "\n" if ( $DEBUG );
            last;
        }

        $n += 1;
    }
    
    $img->close;
    print "RETURN: DONE READING DATA #2", "\n" if ( $DEBUG );
    return $result;
    
}

1;

