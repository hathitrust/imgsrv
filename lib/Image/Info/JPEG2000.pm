package Image::Info::JPEG2000;

use IO::File;

sub ImageInfo {
    return image_info(@_);
}

sub process_file {
    my($info, $fh) = @_;
    my $result = image_info($fh);
    foreach my $key ( keys %$result ) {
        $info->push_info(0, $key => $$result{$key});
    }
}

sub image_info {
    my ( $filename ) = @_;
    my $fh = ref($filename) ? $filename : new IO::File $filename;
    my ( $tests, $data ) = BoxValidator->new("JP2", $fh)->validate();
    my $result = {
        width => $$data{'jp2HeaderBox/imageHeaderBox/width'},
        height => $$data{'jp2HeaderBox/imageHeaderBox/height'},
        layers => $$data{'contiguousCodestreamBox/cod/layers'},
        levels => $$data{'contiguousCodestreamBox/cod/levels'},
    };

    if ( $$data{'jp2HeaderBox/colourSpecificationBox/enumCS'} == 16 ) {
        $$result{ColorSpace} = qq{sRGB};
    } elsif ( $$data{'jp2HeaderBox/colourSpecificationBox/enumCS'} == 17 ) {
        $$result{ColorSpace} = qq{sLUM};
    } elsif ( $$data{'jp2HeaderBox/colourSpecificationBox/enumCS'} == 18 ) {
        $$result{ColorSpace} = qq{sYCC};
    }

    if ( $$data{'resolutionBox/captureResolutionBox/vRescInPixelsPerInch'} ) {
        $$result{XResolution} = $$data{'resolutionBox/captureResolutionBox/hRescInPixelsPerInch'};
        $$result{YResolution} = $$data{'resolutionBox/captureResolutionBox/vRescInPixelsPerInch'};
        $$result{ResolutionUnit} = 'inches';
    } elsif ( $$data{'jp2HeaderBox/resolutionBox/captureResolutionBox/vRescInPixelsPerInch'} ) {
        $$result{XResolution} = $$data{'jp2HeaderBox/resolutionBox/captureResolutionBox/hRescInPixelsPerInch'};
        $$result{YResolution} = $$data{'jp2HeaderBox/resolutionBox/captureResolutionBox/vRescInPixelsPerInch'};
        $$result{ResolutionUnit} = 'inches';
    }

    return $result;
}


package BoxValidator;
use Data::Dumper;
use File::stat;


our $typeMap = {
		"\x6a\x70\x32\x69"=> "intellectualPropertyBox",
		"\x78\x6d\x6c\x20"=> "xmlBox",
		"\x75\x75\x69\x64"=> "uuidBox",
		"\x75\x69\x6e\x66"=> "uuidInfoBox",
		"\x6a\x50\x20\x20"=> "signatureBox",
		"\x66\x74\x79\x70"=> "fileTypeBox",
		"\x6a\x70\x32\x68"=> "jp2HeaderBox",
		"\x69\x68\x64\x72"=> "imageHeaderBox",
		"\x62\x70\x63\x63"=> "bitsPerComponentBox",
		"\x63\x6f\x6c\x72"=> "colourSpecificationBox",
		"\x70\x63\x6c\x72"=> "paletteBox",
		"\x63\x6d\x61\x70"=> "componentMappingBox",
		"\x63\x64\x65\x66"=> "channelDefinitionBox",
		"\x72\x65\x73\x20"=> "resolutionBox",
		"\x6a\x70\x32\x63"=> "contiguousCodestreamBox",
		"\x72\x65\x73\x63"=> "captureResolutionBox",
		"\x72\x65\x73\x64"=> "displayResolutionBox",
		"\x75\x6c\x73\x74"=> "uuidListBox",
		"\x75\x72\x6c\x20"=> "urlBox",
		"\xff\x51"=> "siz",
		"\xff\x52"=> "cod",
		"\xff\x5c"=> "qcd",
		"\xff\x64"=> "com",
		"\xff\x90"=> "tilePart",
		"icc"=> "icc",
		"startOfTile"=> "sot"
};

our $boxTagMap = {};
foreach my $key ( keys %$typeMap ) {
    $$boxTagMap{$$typeMap{$key}} = $key;
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

sub new {
    my ($class, $bType, $boxContents, $startOffset, $size) = @_;
    my $self = {};
    bless($self, $class);
    
    $$self{boxContentsLength} = $size;
    $$self{startOffset} = $startOffset || 0;
    
    if ( $$typeMap{$bType} ) {
        $$self{boxType} = $$typeMap{$bType};
        #### print STDERR "--- BTYPE : ", length($bType), "\n";
        ## $$self{boxContentsLength} -=( length($bType) * 2 );
    } elsif ( $bType eq 'JP2' ) {
        $$self{characteristics} = {};
        $$self{tests} = {};
        $$self{boxType} = 'JP2';
        $$self{boxContentsLength} = stat($boxContents)->size;
    } else {
        #### print STDERR _dump($bType), "\n";
        $$self{boxType} = 'unknownBox';
    }
    
    if ( $$self{boxType} ne 'JP2' ) {
        $$self{characteristics} = {};
        $$self{tests} = {};
    }
    
    $$self{boxContents} = $boxContents;
    unless(ref($$self{boxContents})) {
        $$self{boxContentsLength} = length($$self{boxContents});
    }
    $$self{returnOffset} = undef;
    $$self{isValid} = undef;
    
    # $$self{boxContents}->seek($startOffset, 0)
    
    #### print STDERR "AHOY: $$self{boxType} :: $$self{boxContentsLength} :: $$self{startOffset}\n";
    
    return $self;
    
}

sub boxContents {
    my ( $self, $start, $end ) = @_;
    if ( ref($$self{boxContents}) ) {
        # file reference
        my $retval;
        $$self{boxContents}->seek($$self{startOffset} + $start, 0);
        
        $$self{boxContents}->read($retval, $end - $start);
        #### print STDERR "BOX CONTENTS FH: $$self{startOffset} / $start / $end / " . ( $end - $start) . " : " . length($retval) . "\n";
        return $retval;
    } elsif ( $start || $end ) {
        # print STDERR "BOX CONTENTS: $start / $end / " . length(substr($$self{boxContents}, $start, $end)) . "\n";
        return substr($$self{boxContents}, $start, ($end - $start));
    }
    return $$self{boxContents};
}

sub validate {
    my ( $self ) = @_;
    
    eval {
      my $to_call =  "validate_" . $$self{boxType};
      $self->$to_call();
    };
    if ( my $err = $@ ) {
        print STDERR "Ignoring: '$$self{boxType}' (validator function not yet implemented)\n";
        print STDERR $err, "\n";
    }
    
    # if ( $$self{isValid} ) {
    #     return ( $$self{isValid}, $$self{tests}, $$self{characteristics} );
    # } elsif ( ! defined $$self{returnOffset} ) {
    #     return ( $$self{tests}, $$self{characteristics} );
    # } else {
    #     return ( $$self{tests}, $$self{characteristics}, $$self{returnOffset} );
    # }

    if ( ! defined $$self{returnOffset} ) {
        return ( $$self{tests}, $$self{characteristics} );
    } else {
        return ( $$self{tests}, $$self{characteristics}, $$self{returnOffset} );
    }
    
}

sub _isValid {
    my ( $self ) = @_;
    for my $key ( keys %{ $$self{tests} } ) {
        if ( $$self{tests}{$key} eq 'False' ) {
            return 0;
        }
    }
    return 1;
}

sub _getBox {
    my ( $self, $byteStart, $noBytes ) = @_;
    
    # box length (4 byte unsigned integer)
    my $boxLengthValue = $self->bytesToUInt($self->boxContents($byteStart, $byteStart + 4));
    ## print STDERR "BOX LENGTH VALUE: $boxLengthValue :: $byteStart\n";
    
    # box type
    my $boxType = $self->boxContents($byteStart+4, $byteStart+8);
    ## print STDERR "BOX TYPE: ", _dump($boxType), "\n";
    
    # start byte of box contents
    my $contentsStartOffset = 8;
    
    # Read extended box length if box length value equals 1
    # In that case contentsStartOffset should also be 16 (not 8!)
    # (See ISO/IEC 15444-1 Section I.4)
    if ( $boxLengthValue == 1 ) {
        
        $boxLengthValue = $self->bytesToULongLong($self->boxContents($byteStart+8, $byteStart+16));
        $contentsStartOffset = 16;
    }
    
    # For the very last box in a file boxLengthValue may equal 0, so we need
    # to calculate actual value
    if ( $boxLengthValue == 0 ) {
        # print STDERR "--- BOXLENGTHVALUE = 0\n";
        $boxLengthValue = $noBytes-$byteStart;
    } else {
        #### print STDERR "--- BOXLENGTHVALUE = $boxLengthValue\n";
    }
    
    # End byte for current box
    $byteEnd = $byteStart + $boxLengthValue;
    
    # Contents of this box as a byte object (i.e. 'DBox' in ISO/IEC 15444-1 Section I.4)
    #### print STDERR "CONTENTS: ", $byteStart+$contentsStartOffset, " // ", $byteEnd, "\n";
    ### my $boxContents = $self->boxContents($byteStart+$contentsStartOffset, $byteEnd);
    
    return ($boxLengthValue, $boxType, $byteStart+$contentsStartOffset, $byteEnd, );
    
}

sub _getMarkerSegment {
    my ( $self, $offset) = @_;
    
    # Read marker segment that starts at offset and return marker, size,
    # contents and start offset of next marker
    
    # First 2 bytes: 16 bit marker
    my $marker = $self->boxContents($offset, $offset+2);
    my $length;
    
    # Check if this is a delimiting marker segment
    my $delim = ();
    $delim{"\xff\x4f"} = 1;
    $delim{"\xff\x93"} = 1;
    $delim{"\xff\xd9"} = 1;
    $delim{"\xff\x92"} = 1;
    
    #### print STDERR "-- MARKER SEGMENT : ", _dump($marker), "\n";
    if ( $delim{$marker} ) {
        # Zero-length markers: SOC, SOD, EOC, EPH
        $length=0
    } else {
        # Not a delimiting marker, so remainder contains some data
        $length=$self->bytesToUShortInt($self->boxContents($offset+2, $offset+4));
        #### print STDERR "-- LENGTH: ", $length, " / ", _dump($self->boxContents($offset+2, $offset+4)), "\n";
    }
        
    # Contents of marker segment (excluding marker) to binary string
    my $contents=$self->boxContents($offset+2, $offset + 2 + $length);
    
    my $offsetNext;
    if ( $length == -9999 ) {
        # If length couldn't be determined because of decode error,
        # return bogus value for offsetNext (calling function should
        # handle this further!)
        $offsetNext=-9999;
    } else {
        # Offset value start of next marker segment
        $offsetNext=$offset+$length+2;
    }
    
    ## print STDERR "MARKER SEGMENT : ", _dump($marker), " : ", $length, " : ", length($contents), " : ", $offsetNext, "\n";
    return($marker,$length,$contents,$offsetNext);
}

sub _calculateCompressionRatio {
    my ( $self, $noBytes, $bPCDepthValues, $height, $width) = @_;
    
    # Computes compression ratio
    # noBytes: size of compressed image in bytes
    # bPCDepthValues: list with bits per component for each component
    # height, width: image height, width
    
    # Total bits per pixel
    my $bitsPerPixel = 0;
    
    for ( my $i = 0; $i <  length(@$bPCDepthValues); $i++ ) {
        $bitsPerPixel += $$bPCDepthValues[$i];
    }
    
    # Convert to bytes per pixel
    my $bytesPerPixel = $bitsPerPixel/8;
    
    # Uncompressed image size
    my $sizeUncompressed = $bytesPerPixel*$height*$width;
    
    # Compression ratio
    my $compressionRatio;
    if ( $noBytes != 0 ) {
        $compressionRatio = $sizeUncompressed / $noBytes;        
    } else {
        # Obviously something going wrong here ...
        $compressionRatio = -9999;
    }
    
    return($compressionRatio) ;
}

sub _getBitValue {
    my ($self, $n, $p) = @_;
    # Get the bit value of denary (base 10) number n at the equivalent binary
    # position p (binary count starts at position 1 from the left)
    # Only works if n can be expressed as 8 bits !!!

    # Word length in bits
    my $wordLength=8;

    # Shift = word length - p
    my $shift= $wordLength- $p;

    return ($n >> $shift) & 1;
}

sub testFor {
    my ($self, $testType, $testResult) = @_;
    # Add testResult node to tests element tree
    
    #print(config.outputVerboseFlag)
    $$self{tests}{$testType} = [] if ( ! ref($$self{tests}{$testType}) );
    push @{ $$self{tests}{$testType} }, $testResult;
    
    # if ( $config.outputVerboseFlag == False:
    #     # Non-verbose output: only add results of tests that failed 
    #     if testResult==False:
    #         self.tests.appendChildTagWithText(testType, testResult)
    # 
    # else:
    #     # Verbose output, add results of all tests
    #     self.tests.appendChildTagWithText(testType, testResult)
}

sub addCharacteristic {
    my ( $self, $characteristic, $charValue ) = @_;
    
    my $key = join("/", $$self{boxType}, $characteristic);
    if ( $$self{characteristics}{$key} ) {
        unless ( ref($$self{characteristics}{$key}) ) {
            $$self{characteristics}{$key} = [ $$self{characteristics}{$key} ];
        }
        push @{ $$self{characteristics}{$key} }, $charValue;
    } else {
        $$self{characteristics}{$key} = $charValue;
    }
}

sub _merge {
    my ( $self, $data ) = @_;
    #### print STDERR Dumper($data), "\n";
    my $boxType = $$self{boxType};
    $boxType = ( $boxType eq 'JP2' ) ? '' : "$boxType/";
    foreach my $key ( keys %$data ) {
        $$self{characteristics}{qq{$boxType$key}} = $$data{$key};
    }
}

# Validator functions for boxes

sub validate_unknownBox {
    my ( $self ) = @_;
    #### print STDERR "ignoring unknown box\n";
}

sub validate_signatureBox {
    my ( $self ) = @_;
    # Signature box (ISO/IEC 15444-1 Section I.5.2)
            
    # Check box size, which should be 4 bytes
    ### $self->testFor("boxLengthIsValid", (length($self->boxContents()) == 4));

    # Signature (*not* added to characteristics output, because it contains non-printable characters)
    ## $self->testFor("signatureIsValid", ( $self->boxContents(0, 4) eq "\x0d\x0a\x87\x0a" ));
}

sub validate_fileTypeBox {
    my ( $self ) = @_;

    # File type box (ISO/IEC 15444-1 Section I.5.2)
    
    # Determine number of compatibility fields from box length
    ### my $numberOfCompatibilityFields=(length($self->boxContents)-8)/4;
    my $numberOfCompatibilityFields=($$self{boxContentsLength}-8)/4;
    #### print STDERR "---- $numberOfCompatibilityFields :: $$self{boxContentsLength}\n";
    
    # This should never produce a decimal number (would indicate missing data)
    ## self.testFor("boxLengthIsValid", numberOfCompatibilityFields == int(numberOfCompatibilityFields))

    # Brand value
    my $br = $self->boxContents(0, 4);
    $self->addCharacteristic( "br", $br);

    # Is brand value valid?
    ## self.testFor("brandIsValid", br == b'\x6a\x70\x32\x20')

    # Minor version
    my $minV = $self->bytesToUInt($self->boxContents(4, 8));
    $self->addCharacteristic("minV", $minV);

    # Value should be 0
    # Note that conforming readers should continue to process the file
    # even if this field contains siome other value
    ### self.testFor("minorVersionIsValid", minV == 0)

    # Compatibility list (one or more 4-byte fields)
    # Create list object and store all entries as separate list elements
    my $cLList = [];
    my $offset = 8;
    
    #### print STDERR "NUMBER = $numberOfCompatibilityFields\n";
    for ( my $i = 0; $i < $numberOfCompatibilityFields; $i++ ) {
        my $cL = $self->boxContents($offset, $offset+4);
        #### print STDERR "...$offset / $cL / ", length($cL), "\n";
        $self->addCharacteristic("cL", $cL);
        push @$cLList, $cL;
        $offset += 4;
    }
    
    #### print STDERR "OK\n";

    # Compatibility list should contain at least one field with mandatory value.
    # List is considered valid if this value is found.
    ### self.testFor("compatibilityListIsValid", b'\x6a\x70\x32\x20' in cLList)
    
}

sub validate_jp2HeaderBox {

    my ( $self ) = @_;
    
    # JP2 header box (superbox) (ISO/IEC 15444-1 Section I.5.3)
    
    # List for storing box type identifiers
    my $subBoxTypes = [];
    my $noBytes = $$self{boxContentsLength}; # length($self->boxContents);
    my $byteStart = 0;
    my $bytesTotal = 0;

    # Dummy value
    my $boxLengthValue = 10;
    while ( $byteStart < $noBytes && $boxLengthValue != 0 ) {
        my ( $boxLengthValue, $boxType, $byteDataStart, $byteEnd ) = $self->_getBox($byteStart, $noBytes);

        # Validate sub-boxes
        my ( $resultBox, $characteristicsBox ) = BoxValidator->new($boxType, $$self{boxContents}, $byteDataStart + $$self{startOffset}, $byteEnd - $byteDataStart)->validate();

        $byteStart = $byteEnd;

        # Add to list of box types
        push @$subBoxTypes, $boxType;

        # Add analysis results to test results tree
        ### self.tests.appendIfNotEmpty(resultBox)

        # Add extracted characteristics to characteristics tree
        $self->_merge($characteristicsBox);
    }


    # If bPCSign equals 1 and bPCDepth equals 128 (equivalent to bPC field being
    # 255), this box should contain a Bits Per Components box
    my $sign = $$self{'characteristics'}{'imageHeaderBox/bPCSign'};
    my $depth = $$self{'characteristics'}{'imageHeaderBox/bPCDepth'};

    if ( $sign == 1 && $depth == 128 ) {
        ## self.testFor("containsBitsPerComponentBox", self.boxTagMap['bitsPerComponentBox'] in subBoxTypes)
    }


}

# Validator functions for boxes in JP2 Header superbox

sub validate_imageHeaderBox {
    my ( $self ) = @_;
    
    # Image header box (ISO/IEC 15444-1 Section I.5.3.1)    
    # This is a fixed-length box that contains generic image info.

    # Check box length (14 bytes, excluding box length/type fields)

    # Image height and width (both as unsigned integers)
    my $data;
    $data = $self->boxContents(0, 4);
    #### print STDERR "--- HEIGHT: $$self{startOffset}: ", length($data), " :: ", _dump($data), "\n";
    my $height = $self->bytesToUInt($self->boxContents(0, 4));
    $self->addCharacteristic("height", $height);
    my $width = $self->bytesToUInt($self->boxContents(4, 8));
    $self->addCharacteristic("width", $width);

    # Height and width should be within range 1 - (2**32)-1

    # Number of components (unsigned short integer)
    my $nC = $self->bytesToUShortInt($self->boxContents(8,10));
    $self->addCharacteristic("nC", $nC);

    # Number of components should be in range 1 - 16384 (including limits)

    # Bits per component (unsigned character)
    my $bPC = $self->bytesToUnsignedChar($self->boxContents(10,11));

    # Most significant bit indicates whether components are signed (1)
    # or unsigned (0).
    my $bPCSign = $self->_getBitValue($bPC, 1);
    $self->addCharacteristic("bPCSign", $bPCSign);

    # Remaining bits indicate (bit depth - 1). Extracted by applying bit mask of
    # 01111111 (=127)
    my $bPCDepth = ($bPC & 127) + 1;
    $self->addCharacteristic("bPCDepth", $bPCDepth);

    # Bits per component field is valid if:
    # 1. bPCDepth in range 1-38 (including limits)
    # 2. OR bPC equal 255 (indicating that components vary in bit depth)
    # my $bPCDepthIsWithinAllowedRange = 1 <= $bPCDepth <= 38;
    # my $bitDepthIsVariable = 1 <= $bPC <= 255;
    # 
    # my $bPCIsValid;
    # if ( $bPCDepthIsWithinAllowedRange || $bitDepthIsVariable ) {
    #     $bPCIsValid=1;
    # } else {
    #     $bPCIsValid=0;
    # }

    
    # Compression type (unsigned character)
    my $c = $self->bytesToUnsignedChar($self->boxContents(11,12));
    $self->addCharacteristic("c", $c);
    
    # Value should always be 7
    
    # Colourspace unknown field (unsigned character)
    my $unkC = $self->bytesToUnsignedChar($self->boxContents(12,13));
    $self->addCharacteristic("unkC", $unkC);
    
    # Value should be 0 or 1
    
    # Intellectual Property field (unsigned character)
    my $iPR = $self->bytesToUnsignedChar($self->boxContents(13,14));
    $self->addCharacteristic("iPR",$iPR);
    
    # Value should be 0 or 1
}


sub validate_bitsPerComponentBox {
    my ( $self ) = @_;
    # bits per component box (ISO/IEC 15444-1 Section I.5.3.2)
    # Optional box that specifies bit depth of each component
    
    # Number of bPC field (each field is 1 byte)
    my $numberOfBPFields = $$self{boxContentsLength}; # length($self->boxContents);

    # Validate all entries
    foreach my $i ( 0 .. $numberOfBPFields ) {

        # Bits per component (unsigned character)
        my $bPC = $self->bytesToUnsignedChar($self->boxContents($i,$i+1));

        # Most significant bit indicates whether components are signed (1)
        # or unsigned (0). Extracted by applying bit mask of 10000000 (=128)
        my $bPCSign = $self->_getBitValue($bPC, 1);
        $self->addCharacteristic("bPCSign",$bPCSign);

        # Remaining bits indicate (bit depth - 1). Extracted by applying bit mask of
        # 01111111 (=127)
        my $bPCDepth=($bPC & 127) + 1;
        $self->addCharacteristic("bPCDepth",$bPCDepth);

        # Bits per component field is valid if bPCDepth in range 1-38 (including limits)
    }

}

sub validate_colourSpecificationBox {
    my ( $self ) = @_;
    
    # Colour specification box (ISO/IEC 15444-1 Section I.5.3.3)
    # This box defines one method for interpreting colourspace of decompressed
    # image data
    
    # Length of this box
    my $length = $$self{boxContentsLength}; # length($self->boxContents);

    # Specification method (unsigned character)
    my $meth = $self->bytesToUnsignedChar($self->boxContents(0,1));
    $self->addCharacteristic("meth",$meth);

    # Value should be 1 (enumerated colourspace) or 2 (restricted ICC profile)

    # Precedence (unsigned character)
    my $prec = $self->bytesToUnsignedChar($self->boxContents(1, 2));
    $self->addCharacteristic("prec",$prec);

    # Value shall be 0 (but conforming readers should ignore it)

    # Colourspace approximation (unsigned character)
    my $approx = $self->bytesToUnsignedChar($self->boxContents(2, 3));
    $self->addCharacteristic("approx",$approx);

    # Value shall be 0 (but conforming readers should ignore it)

    # Colour space info: enumerated CS or embedded ICC profile,
    # depending on value of meth
    if ( $meth == 1 ) {
        # Enumerated colour space field (long integer)
        my $enumCS = $self->bytesToUInt($self->boxContents(3, $length));
        $self->addCharacteristic("enumCS",$enumCS);

        # (Note: this will also trap any cases where enumCS is more/less than 4
        # bytes, as $self->bytesToUInt will return bogus negative value, which in turn is
        # handled by statement below)

        # Legal values: 16,17, 18

    } elsif ( $meth == 2 ) {
        # Restricted ICC profile
        my $profile = $self->boxContents(3, $length);

        # Extract ICC profile properties as element object
        my $tests, $iccCharacteristics = BoxValidator->new('icc', $profile)->validate(); #self.getICCCharacteristics(profile)
        $self->_merge($iccCharacteristics);

        # Profile size property should equal actual profile size
        my $profileSize = $$iccCharacteristics{'profileSize'};

        # Profile class must be 'input' or 'display'
        my $profileClass = $$iccCharacteristics{'profileClass'};

        # List of tag signatures may not contain "AToB0Tag", which indicates
        # an N-component LUT based profile, which is not allowed in JP2

        # Step 1: create list of all "tag" elements
        my $tagSignatureElements = $$iccCharacteristics{'tag'};

        # Step 2: create list of all tag signatures and fill it
        # my $tagSignatures=[]
        # 
        # foreach my $tag ( @$tagSignatureElements ) {
        #     push @$tagSignatures, $tag;
        # }

        # Step 3: verify non-existence of "AToB0Tag"

    } elsif ( $meth == 3 ) {
        # ICC profile embedded using "Any ICC" method. Belongs to Part 2 of the
        # standard (JPX), so if we get here by definition this is not valid JP2!
        my $profile = $self->boxContents(3, $length);

        # Extract ICC profile properties as element object
        my ( $tests, $iccCharacteristics ) = BoxValidator->new('icc', $profile)->validate(); #self.getICCCharacteristics(profile)
        $self->_merge($iccCharacteristics);
    }
        
}

sub validate_icc {
    my ( $self ) = @_;
}

sub validate_paletteBox {
    my ( $self ) = @_;
}

sub validate_componentMappingBox {
    my ( $self ) = @_;
    
    # Component mapping box (ISO/IEC 15444-1 Section I.5.3.5)
    # This box defines how image channels are identified from actual components
    
    # Determine number of channels from box length
    ### my $numberOfChannels=int(length($self->boxContents)/4);
    my $numberOfChannels=int(($$self{boxContentsLength})/4);
    
    my $offset=0;

    # Loop through box contents and validate fields
    foreach my $i ( 0 .. $numberOfChannels ) {
        
        # Component index
        my $cMP=$self->bytesToUShortInt($self->boxContents($offset,$offset+2));
        $self->addCharacteristic("cMP",$cMP);

        # Allowed range: 0 - 16384

        # Specifies how channel is generated from codestream component
        my $mTyp = $self->bytesToUnsignedChar($self->boxContents($offset+2, $offset+3));
        $self->addCharacteristic("mTyp",$mTyp);

        # Allowed range: 0 - 1

        # Palette component index
        my $pCol = $self->bytesToUnsignedChar($self->boxContents($offset+3,$offset+4));
        $self->addCharacteristic("pCol",$pCol);

        # If mTyp equals 0, pCol should be 0 as well
        my $pColIsValid = 1;
        if ( $mTyp ==0 ) {
            $pColIsValid = ($pCol ==0);
        } else {
            $pColIsValid=1;
        }
        

        $offset += 4         ;
    }
    

}

sub validate_channelDefinitionBox {
    my ( $self ) = @_;
}

sub validate_resolutionBox {
    my ( $self ) = @_;

    # Marker tags/codes that identify all sub-boxes as hexadecimal strings
    my $tagCaptureResolutionBox=qq{\x72\x65\x73\x63};
    my $tagDisplayResolutionBox=qq{\x72\x65\x73\x64};

    # List for storing box type identifiers
    my $subBoxTypes=[];

    my $noBytes = $$self{boxContentsLength};
    my $byteStart = 0;
    my $bytesTotal = 0;

    # Dummy value
    my $boxLengthValue = 10;

    while ( $byteStart < $noBytes && $boxLengthValue != 0 ) {
        my ( $boxLengthValue, $boxType, $byteDataStart, $byteEnd ) = $self->_getBox($byteStart, $noBytes);

        # my ( $resultBox,$characteristicsBox ) = BoxValidator->new($boxType, $$self{boxContents}, $byteDataStart, $byteEnd - $byteDataStart)->validate();
        my ( $resultBox, $characteristicsBox ) = BoxValidator->new($boxType, $$self{boxContents}, $byteDataStart + $$self{startOffset}, $byteEnd - $byteDataStart)->validate();

        $byteStart = $byteEnd;
        $self->_merge($characteristicsBox);
    }


        # boxLengthValue, boxType, byteEnd, subBoxContents = self._getBox(byteStart, noBytes)

        # # validate sub boxes
        # resultBox, characteristicsBox = BoxValidator(boxType, subBoxContents).validate()

        # byteStart = byteEnd

        # # Add to list of box types
        # subBoxTypes.append(boxType)

        # # Add analysis results to test results tree
        # self.tests.append(resultBox)

        # # Add extracted characteristics to characteristics tree
        # self.characteristics.append(characteristicsBox)
}

sub validate_captureResolutionBox {
    my ( $self ) = @_;

    # Capture  Resolution Box (ISO/IEC 15444-1 Section I.5.3.7.1)

    # Vertical / horizontal grid resolution numerators and denominators:
    # all values within range 1-65535

    # Vertical grid resolution numerator (2 byte integer)
    my $vRcN = $self->bytesToUShortInt($self->boxContents(0,2));
    $self->addCharacteristic("vRcN", $vRcN);
    # self.testFor("vRcNIsValid", 1 <= vRcN <= 65535)

    # Vertical grid resolution denominator (2 byte integer)
    my $vRcD = $self->bytesToUShortInt($self->boxContents(2,4));
    $self->addCharacteristic("vRcD", $vRcD);
    # self.testFor("vRcDIsValid", 1 <= vRcD <= 65535)

    # Horizontal grid resolution numerator (2 byte integer)
    my $hRcN = $self->bytesToUShortInt($self->boxContents(4,6));
    $self->addCharacteristic("hRcN", $hRcN);
    # self.testFor("hRcNIsValid", 1 <= hRcN <= 65535)

    # Horizontal grid resolution denominator (2 byte integer)
    my $hRcD = $self->bytesToUShortInt($self->boxContents(6,8));
    $self->addCharacteristic("hRcD", $hRcD);
    # self.testFor("hRcDIsValid", 1 <= hRcD <= 65535)

    # Vertical / horizontal grid resolution exponents:
    # values within range -128-127

    # Vertical grid resolution exponent (1 byte signed integer)
    my $vRcE = $self->bytesToSignedChar($self->boxContents(8,9));
    $self->addCharacteristic("vRcE", $vRcE);
    # self.testFor("vRcEIsValid", -128 <= vRcE <= 127)

    # Horizontal grid resolution exponent (1 byte signed integer)
    my $hRcE = $self->bytesToSignedChar($self->boxContents(9,10));
    $self->addCharacteristic("hRcE", $hRcE);
    # self.testFor("hRcEIsValid", -128 <= hRcE <= 127)

    # Include vertical and horizontal resolution values in pixels per meter
    # and pixels per inch in output
    my $vRescInPixelsPerMeter = ($vRcN/$vRcD) * (10**($vRcE));
    $self->addCharacteristic("vRescInPixelsPerMeter", round($vRescInPixelsPerMeter,2));

    my $hRescInPixelsPerMeter = ($hRcN/$hRcD) * (10**($hRcE));
    $self->addCharacteristic("hRescInPixelsPerMeter", round($hRescInPixelsPerMeter,2));

    my $vRescInPixelsPerInch = $vRescInPixelsPerMeter * 25.4e-3;
    $self->addCharacteristic("vRescInPixelsPerInch", round($vRescInPixelsPerInch,2));

    my $hRescInPixelsPerInch = $hRescInPixelsPerMeter * 25.4e-3;
    $self->addCharacteristic("hRescInPixelsPerInch", round($hRescInPixelsPerInch,2));

}

sub validate_displayResolutionBox {
    my ( $self ) = @_;
}

sub validate_contiguousCodestreamBox {
    my ( $self ) = @_;
    
    # Contiguous codestream box (ISO/IEC 15444-1 Section I.5.4)
    
    # Codestream length
    my $length = $$self{boxContentsLength}; # length($self->boxContents);

    # Keep track of byte offsets
    my $offset = 0;

    # Read first marker segment. This should be the start-of-codestream marker
    my ( $marker,$segLength,$segContents,$offsetNext ) = $self->_getMarkerSegment($offset);
    #### print STDERR "INIT = ", _dump($marker), " / ", length($segContents), " / ", $offsetNext, "\n";

    # Marker should be start-of-codestream marker
    $offset = $offsetNext;

    # Read next marker segment. This should be the SIZ (image and tile size) marker
    ( $marker,$segLength,$segContents,$offsetNext ) = $self->_getMarkerSegment($offset);
    my $foundSIZMarker = ($marker eq "\xff\x51" );
    
    #### print STDERR "SIZ = ", _dump($marker), " / ", length($segContents), " / ", $offsetNext, "\n";

    if ( $foundSIZMarker ) {
        # Validate SIZ segment
        my ( $resultSIZ, $characteristicsSIZ ) = BoxValidator->new($marker, $segContents)->validate(); # validateSIZ(segContents)

        # Add analysis results to test results tree
        #self.tests.appendIfNotEmpty(resultSIZ)
        
        ## self.tests.appendIfNotEmpty(resultSIZ)
        
        # Add extracted characteristics to characteristics tree
        # self.characteristics.append(characteristicsSIZ)
        $self->_merge($characteristicsSIZ);
    }

    $offset = $offsetNext;

    # Loop through remaining marker segments in main header; first SOT (start of
    # tile-part marker) indicates end of main header. For now only validate
    # COD and QCD segments (which are both required) and extract contents of
    # COM segments. Any other marker segments are ignored.

    # Initial values for foundCODMarker and foundQCDMarker
    my $foundCODMarker=0;
    my $foundQCDMarker=0;

    while ( $marker ne "\xff\x90" && $offsetNext != -9999 ) {
        ( $marker,$segLength,$segContents,$offsetNext ) =$self->_getMarkerSegment($offset);
        #### print STDERR "MARKER : ", $offset, " / ", _dump($marker), "\n";

        if ( $marker eq "\xff\x52" ) {
            # COD (coding style default) marker segment
            # COD is required
            $foundCODMarker=1;

            # Validate COD segment
            my ( $resultCOD, $characteristicsCOD ) = BoxValidator->new($marker, $segContents)->validate() ;
            # Add analysis results to test results tree
            ### self.tests.appendIfNotEmpty(resultCOD)
            # Add extracted characteristics to characteristics tree
            ## #self.characteristics.append(characteristicsCOD)
            $self->_merge($characteristicsCOD);
            $offset = $offsetNext;
        } elsif ( $marker eq "\xff\x5c" ) {
            # QCD (quantization default) marker segment
            # QCD is required
            $foundQCDMarker=1;
            # Validate QCD segment
            my ( $resultQCD, $characteristicsQCD ) = BoxValidator->new($marker, $segContents)->validate();
            # Add analysis results to test results tree
            ### self.tests.appendIfNotEmpty(resultQCD)
            # Add extracted characteristics to characteristics tree
            # self.characteristics.append(characteristicsQCD)
            $self->_merge($characteristicsQCD);
            
            $offset=$offsetNext;
        } elsif ( $marker eq "\xff\x64" ) {
            # COM (codestream comment) marker segment
            # Validate QCD segment
            my ( $resultCOM, $characteristicsCOM ) = BoxValidator->new($marker, $segContents)->validate() ;
            # Add analysis results to test results tree
            ### self.tests.appendIfNotEmpty(resultCOM)
            # Add extracted characteristics to characteristics tree
            ## $self.characteristics.append(characteristicsCOM)
            $self->_merge($characteristicsCOM);
            
            $offset = $offsetNext;
        } elsif ( $marker eq "\xff\x90" ) {
            # Start of tile (SOT) marker segment; don't update offset as this
            # will get us of out of this loop (for functional readability):
            $offset = $offset;
        } else {
            # Any other marker segment: ignore and move on to next one
            $offset=$offsetNext;
        }
    }

    # Add foundCODMarker / foundQCDMarker outcome to tests

    # # Check if quantization parameters are consistent with levels (section A.6.4, eq A-4)
    # # Note: this check may be performed at tile-part level as well (not included now)
    # if ( $foundCODMarker ) {
    #     lqcd = self.characteristics.findElementText('qcd/lqcd')
    #     qStyle = self.characteristics.findElementText('qcd/qStyle')
    #     levels = self.characteristics.findElementText('cod/levels')
    # }
    # 
    # # Expected lqcd as a function of qStyle and levels
    # if qStyle == 0:
    #     lqcdExpected = 4 + 3*levels
    # elif qStyle == 1:
    #     lqcdExpected = 5
    # elif qStyle == 2:
    #     lqcdExpected= 5 + 6*levels
    # else:
    #     # Dummy value in case of non-legal value of qStyle
    #     lqcdExpected = -9999
    # 
    # # lqcd should equal expected value
    # 
    # # Remainder of codestream is a sequence of tile parts, followed by one
    # # end-of-codestream marker
    # 
    # # Expected number of tiles (as calculated from info in SIZ marker)
    # numberOfTilesExpected=self.characteristics.findElementText('siz/numberOfTiles')
    # 
    # # Create list with one entry for each tile
    # tileIndices=[]
    # 
    # # Dictionary that contains expected number of tile parts for each tile
    # tilePartsPerTileExpected={}
    # 
    # # Dictionary that contains found number of tile parts for each tile
    # tilePartsPerTileFound={}
    # 
    # # Create entry for each tile part and initialise value at 0
    # for i in range(numberOfTilesExpected):
    #     tilePartsPerTileFound[i]=0
    # 
    # # Create sub-elements to store tile-part characteristics and tests
    # tilePartCharacteristics=ET.Element('tileParts')
    # tilePartTests=ET.Element('tileParts')
    # 
    # while marker == b'\xff\x90':
    #     marker = $self->boxContents[offset:offset+2]
    # 
    #     if marker == b'\xff\x90':
    #         resultTilePart, characteristicsTilePart,offsetNext = BoxValidator(marker, $self->boxContents, offset).validate()
    #         # Add analysis results to test results tree
    #         tilePartTests.appendIfNotEmpty(resultTilePart)
    # 
    #         # Add extracted characteristics to characteristics tree
    #         tilePartCharacteristics.append(characteristicsTilePart)
    #         
    #         tileIndex=characteristicsTilePart.findElementText('sot/isot')
    #         tilePartIndex=characteristicsTilePart.findElementText('sor/tpsot')
    #         tilePartsOfTile=characteristicsTilePart.findElementText('sot/tnsot')
    #         
    #         # Add tileIndex to tileIndices, if it doesn't exist already
    #         if tileIndex not in tileIndices:
    #             tileIndices.append(tileIndex)
    #                     
    #         # Expected number of tile-parts for each tile to dictionary
    #         if tilePartsOfTile != 0:                
    #             tilePartsPerTileExpected[tileIndex]=tilePartsOfTile
    #         
    #         # Increase found number of tile-parts for this tile by 1 
    #         tilePartsPerTileFound[tileIndex]=tilePartsPerTileFound[tileIndex] +1
    # 
    #         if offsetNext != offset:
    #             offset = offsetNext
    # 
    # # Length of tileIndices should equal numberOfTilesExpected
    # 
    # #test = set(tilePartsPerTileExpected.items()) - set(tilePartsPerTileFound.items()) 
    # 
    # #print(len(test))
    # 
    # # Found numbers of tile parts per tile should match expected    
    # 
    # # Add tile-part characteristics and tests to characteristics / tests
    # self.characteristics.append(tilePartCharacteristics)
    # self.tests.appendIfNotEmpty(tilePartTests)
    # 
    # # Last 2 bytes should be end-of-codestream marker
}

sub validate_siz {
    my ( $self ) = @_;
}

sub validate_cod {
    my ( $self ) = @_;
    
    # Coding style default (COD) header fields (ISO/IEC 15444-1 Section A.6.1)

    # Length of COD marker
    my $lcod=$self->bytesToUShortInt($self->boxContents(0, 2));
    $self->addCharacteristic("lcod",$lcod);

    # lcod should be in range 12-45
    # my $lcodIsValid= 12 <= $lcod  <= 45;

    # Coding style
    my $scod=$self->bytesToUnsignedChar($self->boxContents(2, 3));

    # scod contains 3 coding style parameters that follow from  its 3 least
    # significant bits

    # Last bit: 0 in case of default precincts (ppx/ppy=15), 1 in case precincts
    # are defined in sPcod parameter
    my $precincts=$self->_getBitValue($scod,8);
    $self->addCharacteristic("precincts",$precincts);

    # 7th bit: 0: no start of packet marker segments; 1: start of packet marker
    # segments may be used
    my $sop=$self->_getBitValue($scod,7);
    $self->addCharacteristic("sop",$sop);

    # 6th bit: 0: no end of packet marker segments; 1: end of packet marker
    # segments shall be used
    my $eph=$self->_getBitValue($scod, 6);
    $self->addCharacteristic("eph",$eph);

    # Coding parameters that are independent of components (grouped as sGCod)
    # in standard)

    my $sGcod=$self->boxContents(3, 7);

    # Progression order
    my $order=$self->bytesToUnsignedChar(substr($sGcod,0, 1));
    $self->addCharacteristic("order",$order);

    # Allowed values: 0 (LRCP), 1 (RLCP), 2 (RPCL), 3 (PCRL), 4(CPRL)
    ### orderIsValid=order in [0,1,2,3,4]

    # Number of layers
    my $layers=$self->bytesToUShortInt(substr($sGcod,1, 2)); # [1:3]
    $self->addCharacteristic("layers",$layers);

    # layers should be in range 1-65535
    # my $layersIsValid=1 <= layers  <= 65535

    # Multiple component transformation
    my $multipleComponentTransformation=$self->bytesToUnsignedChar(substr($sGcod,3, 1)); # [3:4]
    $self->addCharacteristic("multipleComponentTransformation",$multipleComponentTransformation);

    # Value should be 0 (no transformation) or 1 (transformation on components
    # 0,1 and 2)
    ## multipleComponentTransformationIsValid=multipleComponentTransformation in [0,1]

    # Coding parameters that are component-specific (grouped as sPCod)
    # in standard)

    # Number of decomposition levels
    my $levels=$self->bytesToUnsignedChar($self->boxContents(7, 8));
    $self->addCharacteristic("levels",$levels);

    # levels should be within range 0-32
    ### levelsIsValid=0 <= levels  <= 32

    # Check lcod is consistent with levels and precincts (eq A-2 )
    my $lcodExpected;
    if ( $precincts ==0 ) {
        $lcodExpected=12;
    } else {
        $lcodExpected=13 + $levels;
    }

    ## lcodConsistentWithLevelsPrecincts=lcod == lcodExpected

    # Code block width exponent (stored as offsets, add 2 to get actual value)
    my $codeBlockWidthExponent=$self->bytesToUnsignedChar($self->boxContents(8, 9)) + 2;
    $self->addCharacteristic("codeBlockWidth",2**$codeBlockWidthExponent);

    # Value within range 2-10
    ### codeBlockWidthExponentIsValid=2 <= codeBlockWidthExponent <= 10

    # Code block height exponent (stored as offsets, add 2 to get actual value)
    my $codeBlockHeightExponent=$self->bytesToUnsignedChar($self->boxContents(9, 10)) + 2;
    $self->addCharacteristic("codeBlockHeight",2**$codeBlockHeightExponent);

    # Value within range 2-10
    # my $codeBlockHeightExponentIsValid=2 <= $codeBlockHeightExponent <= 10;

    # Sum of width + height exponents shouldn't exceed 12
    ## sumHeightWidthExponentIsValid=codeBlockWidthExponent+codeBlockHeightExponent <= 12

    # Code block style, contains 6 boolean switches
    my $codeBlockStyle=$self->bytesToUnsignedChar($self->boxContents(10, 11));

    # Bit 8: selective arithmetic coding bypass
    my $codingBypass=$self->_getBitValue($codeBlockStyle,8);
    $self->addCharacteristic("codingBypass",$codingBypass);

    # Bit 7: reset of context probabilities on coding pass boundaries
    my $resetOnBoundaries=$self->_getBitValue($codeBlockStyle,7);
    $self->addCharacteristic("resetOnBoundaries",$resetOnBoundaries);

    # Bit 6: termination on each coding pass
    my $termOnEachPass=$self->_getBitValue($codeBlockStyle,6);
    $self->addCharacteristic("termOnEachPass",$termOnEachPass);

    # Bit 5: vertically causal context
    my $vertCausalContext=$self->_getBitValue($codeBlockStyle,5);
    $self->addCharacteristic("vertCausalContext",$vertCausalContext);

    # Bit 4: predictable termination
    my $predTermination=$self->_getBitValue(codeBlockStyle,4);
    $self->addCharacteristic("predTermination",$predTermination);

    # Bit 3: segmentation symbols are used
    my $segmentationSymbols=$self->_getBitValue($codeBlockStyle,3);
    $self->addCharacteristic("segmentationSymbols",$segmentationSymbols);

    # Wavelet transformation: 9-7 irreversible (0) or 5-3 reversible (1)
    my $transformation=$self->bytesToUnsignedChar($self->boxContents(11, 12));
    $self->addCharacteristic("transformation",$transformation);

    ## transformationIsValid=transformation in [0,1]

    if ( $precincts ==1 ) {

        # Precinct size for each resolution level (=decomposition levels +1)
        # Order: low to high (lowest first)

        $offset=12;

        foreach my $i ( 0 .. ( $levels + 1 ) ) {
            # Precinct byte
            my $precinctByte=$self->bytesToUnsignedChar($self->boxContents($offset, $offset+1));

            # Precinct width exponent: least significant 4 bytes (apply bit mask)
            my $ppx=$precinctByte & 15;
            my $precinctSizeX=2**$ppx;
            $self->addCharacteristic("precinctSizeX",$precinctSizeX);

            # Precinct size of 1 (exponent 0) only allowed for lowest resolution level
            # if ( $i !=0 ) 
            #     precinctSizeXIsValid=precinctSizeX >= 2
            # else:
            #     precinctSizeXIsValid=True


            # Precinct height exponent: most significant 4 bytes (shift 4
            # to right and apply bit mask)
            my $ppy=($precinctByte >>4) & 15;
            my $precinctSizeY=2**$ppy;
            $self->addCharacteristic("precinctSizeY",$precinctSizeY);

            # Precinct size of 1 (exponent 0) only allowed for lowest resolution level
            # if i !=0:
            #     precinctSizeYIsValid=precinctSizeY >= 2
            # else:
            #     precinctSizeYIsValid=True

            $offset+=1;
        }
    }
    
}

sub validate_qcd {
    my ( $self ) = @_;
}

sub validate_com {
    my ( $self ) = @_;
}

sub validate_sot {
    my ( $self ) = @_;
}

sub validate_tilePart {
    my ( $self ) = @_;
}

sub validate_xmlBox {
    my ( $self ) = @_;
}

sub validate_uuidBox {
    my ( $self ) = @_;
}

sub validate_uuidInfoBox {
    my ( $self ) = @_;
}

sub validate_uuidListBox {
    my ( $self ) = @_;
}

sub validate_urlBox {
    my ( $self ) = @_;   
}

sub validate_JP2 {
    my ( $self ) = @_;
    
    # Top-level function for JP2 validation:
    #
    # 1. Parses all top-level boxes in JP2 byte object, and calls separate validator
    #   function for each of these
    # 2. Checks for presence of all required top-level boxes
    # 3. Checks if JP2 header properties are consistent with corresponding properties
    #   in codestream header

    # Marker tags/codes that identify all top level boxes as hexadecimal strings
    #(Correspond to "Box Type" values, see ISO/IEC 15444-1 Section I.4)
    my $tagSignatureBox="\x6a\x50\x20\x20";
    my $tagFileTypeBox="\x66\x74\x79\x70";
    my $tagJP2HeaderBox="\x6a\x70\x32\x68";
    my $tagContiguousCodestreamBox="\x6a\x70\x32\x63";

    # List for storing box type identifiers
    my $boxTypes=[];

    my $noBytes=$$self{'boxContentsLength'};
    my $byteStart = 0;
    my $bytesTotal=0;

    # Dummy value
    my $boxLengthValue=10;
    
    #### print "NO BYTES = $noBytes\n";

    while ( $byteStart < $noBytes && $boxLengthValue != 0 ) {

        my ( $boxLengthValue, $boxType, $byteDataStart, $byteEnd ) = $self->_getBox($byteStart, $noBytes);
        
        # print "::: GOTTEN BOX :: ", $boxLengthValue, " :: ", _dump($boxType), " :: $byteStart / $byteEnd :: $byteDataStart", "\n";
        # print "::: ", length($boxType), " :: ", ( $boxLengthValue - length($boxType) ), "\n";

        # Validate current top level box
        my ( $resultBox,$characteristicsBox ) = BoxValidator->new($boxType, $$self{boxContents}, $byteDataStart, $byteEnd - $byteDataStart)->validate();

        $byteStart = $byteEnd;

        # Add to list of box types
        ## boxTypes.append(boxType)

        # Add analysis results to test results tree
        ### self.tests.appendIfNotEmpty(resultBox)

        # Add extracted characteristics to characteristics tree
        ### self.characteristics.append(characteristicsBox)
        $self->_merge($characteristicsBox);
        ## last if ( scalar keys %{$$self{characteristics}} );
    }


    # Valid JP2 only if all tests returned True
    ## self.isValid = self._isValid()
    
}

## byteconv

sub bytesToULongLong {
    my ( $self, $bytes ) = @_;
	# Unpack 8 byte string to unsigned long long integer, assuming big-endian byte order.
	return _doConv($bytes, ">", "Q")
}

sub bytesToUInt {
    my ( $self, $bytes ) = @_;
	# Unpack 4 byte string to unsigned integer, assuming big-endian byte order.
	return _doConv($bytes, ">", "I");
}

sub bytesToUShortInt {
    my ( $self, $bytes ) = @_;
	# Unpack 2 byte string to unsigned short integer, assuming big-endian  byte order
	return _doConv($bytes, "!", "H")
}

sub bytesToUnsignedChar {
    my ( $self, $bytes ) = @_;
	# Unpack 1 byte string to unsigned character/integer, assuming big-endian  byte order.
	return _doConv($bytes, ">", "B")
}

sub bytesToSignedChar {
    my ( $self, $bytes ) = @_;
	# Unpack 1 byte string to signed character/integer, assuming big-endian byte order.
	return _doConv($bytes, ">", "b")
}
	
sub bytesToInteger {
    my ( $self, $bytes ) = @_;
	# Unpack byte string of any length to integer.
	#
	# Taken from:
	# http://stackoverflow.com/questions/4358285/
	#
	# JvdK: what endianness is assumed here? Could go wrong on some systems?

	# binascii.hexlify will be obsolete in python3 soon
	# They will add a .tohex() method to bytes class
	# Issue 3532 bugs.python.org
	
    # try:
    #   result=int(binascii.hexlify(bytes),16)
    # except:
    #   result=-9999
	
	return (result)
    
}

sub _doConv {
    my ( $bytes, $bOrder, $formatCharacter ) = @_;
    my $formatStr = $formatCharacter;
    my @bits = split(//, $bytes);
    my $retval;
    # if ( $bOrder eq '!' ) {
    #     print STDERR "---- # BITS ", length($bytes), " :: ", scalar @bits, "\n";
    #     print STDERR _dump($bytes) . "\n";
    # }
    if ( length($bytes) == 4 ) {
        $retval = (ord($bits[0]) << 24) + (ord($bits[1]) << 16) + (ord($bits[2]) << 8) + ord($bits[3]);
    } elsif ( length($bytes) == 2 ) {
        $retval = (ord($bits[0]) << 8) + ord($bits[1]);
    } elsif ( scalar @bits == 3 ) {
        $retval = (ord($bits[0]) << 16) + (ord($bits[1]) << 8) + ord($bits[2]);
        # print STDERR "---- ", $retval, "\n";
    } elsif ( length($bytes) == 8 ) {
        $retval =  
            (ord($bits[0]) << 52) + 
            (ord($bits[1]) << 48) + 
            (ord($bits[2]) << 40) + 
            (ord($bits[3]) << 32) + 
            (ord($bits[4]) << 24) + 
            (ord($bits[5]) << 16) + 
            (ord($bits[6]) << 8) + 
            ord($bits[7]);
    } elsif ( length($bytes) == 1 ) {
        $retval = unpack("c", $bytes);
    }
    return $retval;
    
    # my @result = unpack($formatStr, $bytes);
    # print $formatStr . " :: " . _dump($bytes), "\n";
    # print Dumper(\@result), "\n"; exit;
    # return $result[0];
}

sub round {
    my ( $num, $precision ) = @_;
    my $template = "%.0$precision" . "f";
    return sprintf($template, $num);
}


1;

# package main;

# use IO::File;
# use Data::Dumper;

# my $filename = shift @ARGV;
# my $fh = new IO::File ($filename);

# # my $filedata = '';
# # while ( my $line = <$fh> ) {
# #     $filedata .= $line;
# # }

# use Time::HiRes qw(time);
# # $fh->seek(0, 0);
# my $t0 = time();
# my ( $tests, $data ) = BoxValidator->new("JP2", $fh)->validate();
# my $delta = time() - $t0;
# print Dumper($data);

# print "DELTA = $delta\n";