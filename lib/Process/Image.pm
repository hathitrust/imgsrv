package Process::Image;
use feature qw(say);

use strict;
use warnings;
use IPC::Run;
use MIME::Types;
use File::Basename qw(dirname basename fileparse);
use File::stat;
use File::Copy;

use Image::Utils;

use Data::Dumper;

use JSON::XS;

use POSIX qw(ceil floor);

use Plack::Util::Accessor qw(
    mdpItem
    region
    size
    target_ppi
    rotation
    quality
    format
    restricted
    blank
    max_dim
    watermark
    logfile
    tmpfilename
);

use Try::Tiny;

use Process::Globals;

use Time::HiRes qw(time);

our $MIN_IMAGE_SIZE = 5;

our $mimetypes = MIME::Types->new;

my $MIME_TO_EXT = {
    'image/jpeg' => 'jpg',
    'image/tiff' => 'tif',
    'image/png'  => 'png',
    'image/gif'  => 'gif',
};

my $EXT_TO_MIME = { map { $$MIME_TO_EXT{$_} => $_ } keys %$MIME_TO_EXT };

sub new {
    my $class = shift;
    my $options = shift || {};
    $$options{source} = $$options{source} || {};
    $$options{output} = $$options{output} || {};
    $$options{steps} = [];
    $$options{queue} = {};
    my $self = bless $options, $class;

    # defaults
    $self->region($$options{region} || 'full');
    $self->size($$options{size} || 'full');
    $self->rotation($$options{rotation} || 0);
    $self->format($$options{format} || 'image/jpeg');
    $self->quality($$options{quality} || 'default');
    $self->target_ppi($$options{target_ppi} || 0);
    $self;
}

sub source {
    my $self = shift;
    my $hash = $$self{source};
    if ( scalar @_ ) {
        my $args = { @_ };
        $self->_merge($hash, $args);
        $self->_get_file_info($hash);
        # last check for height=1 x width=1
        if ( $$hash{metadata} && $$hash{metadata}{width} == 1 && $$hash{metadata}{height} == 1 ) {
            $self->source( filename => $SRV::Globals::gMissingPageImage );
        }
    }
    $hash;
}

sub output {
    my $self = shift;
    my $hash = $$self{output};
    if ( scalar @_ ) {
        my $args = { @_ };
        $self->_merge($hash, $args);
        $self->_get_file_info($hash, 0);
    }
    $hash;
}

sub process {
    my $self = shift;

    # does the source exist?

    ### process the given paremters
    $self->_setup_sizing();

    # $self->_setup_region();

    $self->_setup_rotation();

    $self->_setup_format();

    ### apply steps
    $self->_process_source();

    $self->_process_sizing();

    ## $self->_process_region();

    $self->_process_rotation();

    $self->_process_watermark();

    $self->_process_output();

    # run all steps
    $self->_run();

    # return target hash
    $self->output->{source_metadata} = $self->source->{metadata};
    $self->output;

}

# STEPS
sub _add_step {
    my $self = shift;
    my $step = shift;
    if ( scalar @{ $$self{steps} } ) {
        push @{ $$self{steps} }, '|';
    }
    push @{ $$self{steps} }, $step;
}

sub _queue_step {
    my $self = shift;
    my $phase = shift;
    my $cmd = shift;
    $$self{queue}{$phase} = $cmd;
}

sub _run {
    my $self = shift;
    return unless ( scalar @{ $$self{steps} } );

    my @commands = ( @{ $$self{steps} }, ">", $self->_target_filename );
    if ( $self->logfile ) {
        push @commands, "2>>", $self->logfile;
    }
    my $t0 = time();
    IPC::Run::run @commands or die "Process: $? " . Dumper(\@commands);

    if ( $self->output->{mimetype} eq 'image/jp2' ) {
        # conver the tmpfilename to a JPEG2000
        my $jp2_tmpfilename = dirname($self->_target_filename) . "/" . time() . "-$$-" . ".jp2";
        my ( $width, $height ) = ($self->output->{metadata}->{width}, $self->output->{metadata}->{height} );
        my $nlev = 0;
        my $max = ( $height > $width ) ? $height : $width;
        while ( $max >= 256 ) {
            $nlev += 1;
            $max = $max / 2;
        }

        IPC::Run::run([
            $Process::Globals::kdu_compress,
            "-num_threads", "0", 
            "Clevels=$nlev",
            "Clayers=8",
            "Creversible=no",
            "Cuse_sop=yes",
            "Cuse_eph=yes",
            "Cmodes=RESET|RESTART|CAUSAL|ERTERM|SEGMARK",
            "Corder=RLCP",
            "-quiet", "-i", 
            $self->tmpfilename, 
            "-o", $jp2_tmpfilename, "-slope", "42988" ]);
        unlink $self->tmpfilename;
        $self->tmpfilename($jp2_tmpfilename);
    }

    ### print STDERR "DELTA: ", ( time() - $t0 ), "\n";

    $self->_cleanup;
}

sub _target_filename {
    my $self = shift;
    return $self->tmpfilename || $self->output->{filename};
}

sub _cleanup {
    my $self = shift;
    if ( $self->tmpfilename ) {
        my $output_filename = $self->output->{filename};
        for( my $try = 0; $try < 3; $try++ ) {
            last if (move($self->tmpfilename, $output_filename));
        }
        if ( -f $self->tmpfilename ) {
            # could not rename; send use tmpfilename
            my $error = $!;
            ## die $!;
            $self->output->{filename} = $self->tmpfilename;
        }
    }
}

sub _setup_sizing {
    my $self = shift;
    my $size = $self->size;
    my $info = $self->source->{metadata};
    my $do_best_fit = 0;
    my $r = -1;

    my ( $max_dim, $min_dim ) = ( 'width', 'height' );
    if ( $$info{width} < $$info{height} ) {
        ($max_dim, $min_dim) = ('height', 'width');
    }

    my $sizing = {};

    if ( $size =~ m,^ppi:\d, ) {
        my ( $target_ppi ) = $size =~ m{^ppi:(\d+)};
        my $meta = Image::Utils::resize($info, $target_ppi);
        my ( $target_w, $target_h ) = ( $$meta{width}, $$meta{height} );
        $size = qq{!$target_w,$target_h};
        $self->target_ppi($target_ppi);
    }


    if ( $size =~ m,^!, ) {
        $size = substr($size, 1);
        $do_best_fit = 1;
    }

    my $pt_size;

    # deal with $size = full
    if ( $size eq 'full' ) {
        $size = q{res:0};
    } elsif ( $size =~ m,^\d+$, || $size =~ m,^size:, ) {
        # PT format
        $size =~ s,^size:,,;
        $pt_size = $size;
        $size = $size / 100;
        $size = floor($Process::Globals::default_width * $size) . ",";
    }

    my $scale_cmd; my $size_dim;
    if ( $size =~ m,^res:, ) {
        $r = int(substr($size, 4));
        if ( $r > $$info{levels} ) {
            $r = $$info{levels};
        }
        $sizing = { width => $$info{width} / ( 2 ** $r ),
                    height => $$info{height} / ( 2 ** $r ),
                    r => $r, exact => 1, do_best_fit => 1 };
    } elsif ( $size =~ m,^pct:, ) {
        my $scale = $size;
        $scale =~ s,^pct:,,;
        $scale = $scale / 100;
        $sizing = { width => floor($$info{width} * $scale),
                    height => floor($$info{height} * $scale),
                    do_best_fit => 1, exact => 0 };
        $size_dim = 'width';


    } else {
        # by number
        my ( $w, $h ) = split(/,/, $size);

        if ( $w ) {
            $w = $$info{width} if ( $w > $$info{width} );
            $size_dim = 'width';
        }
        if ( $h ) {
            $h = $$info{height} if ( $h > $$info{height} );
            $size_dim = 'height';
        }

        $sizing = { width => $w, height => $h, exact => 0, do_best_fit => $do_best_fit };
    }

    # given a number, we can calculate the other number
    if ( $$sizing{width} && ! $$sizing{height} ) {
        my $ratio = $$sizing{width} / $$info{width};
        $$sizing{height} = floor($$info{height} * $ratio);
    } elsif ( $$sizing{height} && ! $$sizing{width} ) {
        my $ratio = $$sizing{height} / $$info{height};
        $$sizing{width} = floor($$info{width} * $ratio);
    }

    if ( $self->max_dim && $$sizing{$max_dim} > $self->max_dim ) {
        my $r = $self->max_dim / $$sizing{$max_dim};
        $$sizing{$max_dim} = $self->max_dim;
        $$sizing{$min_dim} = floor($$sizing{$min_dim} * $r);
    }

    if ( $$sizing{$min_dim} < $MIN_IMAGE_SIZE ) {
        my $r = $MIN_IMAGE_SIZE / $$sizing{$min_dim};
        $$sizing{$min_dim} = $MIN_IMAGE_SIZE;
        $$sizing{$max_dim} = floor($$sizing{$max_dim} * $r);
    }

    unless ( exists $$sizing{r} ) {
        $r = 0;
        my $dim = $$info{$size_dim};
        $r = floor(log( $dim / $$sizing{$size_dim} ) / log(2));

        if ( $dim == $$sizing{$size_dim} ) {
            # found an exact resolution match
            $$sizing{exact} = 1;
        }

        if ( $r > $$info{levels} ) {
            $r = $$info{levels};
        }

        $$sizing{r} = $r;
        $$sizing{do_best_fit} = $do_best_fit;
    }
    
    $$sizing{size} = $pt_size if ( $pt_size );
    $$sizing{XResolution} = $$sizing{YResolution} = $self->target_ppi if ( $self->target_ppi );
    $self->output->{metadata} = $sizing;
}

sub _setup_rotation {
    my $self = shift;
    return if ( $self->rotation == 0 );
    if ( $self->source->{mimetype} eq 'image/jp2' && ( $self->rotation == 90 || $self->rotation == 270 ) ) {
        ( $self->output->{metadata}->{width}, $self->output->{metadata}->{height} ) =
            ( $self->output->{metadata}->{height}, $self->output->{metadata}->{width} );
    }
}

sub _setup_format {
    my $self = shift;
    # really, create the target filename,
    my $ext = $$MIME_TO_EXT{$self->format};
    # my ( $basename, $pathname, $suffix) = fileparse($$hash{filename}, @suffixes );
}

# EXTRACTION

sub _process_source {
    my $self = shift;
    my $mimetype = $self->source->{mimetype};
    my $filename = $self->source->{filename};

    if ( $self->blank ) {
        # generate blank image
        $self->_add_step([$Process::Globals::ppmmake, "rgb:ff/ff/ff", $self->output->{metadata}->{width}, $self->output->{metadata}->{height}]);
    } elsif ( $self->restricted ) {
        # return an SVG blob
        my $info = $self->{output}->{metadata};
        my ( $width, $height ) = ( $$info{width}, $$info{height} );
        if ( $$info{do_best_fit} ) {
            my $r = $width / $self->{source}->{metadata}->{width};
            $height = ceil($self->{source}->{metadata}->{height} * $r);
        }

        my $svg_data = File::Slurp::read_file("$ENV{SDRROOT}/imgsrv/web/graphics/restricted_image.svg");
        $svg_data =~ s,\$\{WIDTH},$width,gsm;
        $svg_data =~ s,\$\{HEIGHT},$height,gsm;
        my $FONT_SIZE = $width * 0.075;
        $svg_data =~ s,\$\{FONT_SIZE},$FONT_SIZE,gsm;

        $self->{output}->{mimetype} = 'image/svg+xml';
        $self->{output}->{data} = $svg_data;
        $self->{output}->{restricted} = 1;

    } elsif ( 0 && $self->restricted ) {
        # generate restricted message
        # original approach: generate PNG --- leaving just in case SVG doesn't pan out
        my $info = $self->{output}->{metadata};
        my ( $width, $height ) = ( $$info{width}, $$info{height} );
        if ( $$info{do_best_fit} ) {
            my $r = $width / $self->{source}->{metadata}->{width};
            $height = ceil($self->{source}->{metadata}->{height} * $r);
        }
        my $d = ( $width < $height ) ? $width : $height;
        $d = int($d * 0.25);

        $self->_add_step([$Process::Globals::pngtopam, "$Process::Globals::restricted_label.png"]);
        $self->_add_step([$Process::Globals::pamscale, "-xsize", ( $width - $d )]);
        my $x_margin = int(( $width - $d ) / 2);
        my $y_margin = int(( $height - $d) / 2);
        $self->_add_step([$Process::Globals::pnmpad, "-black", "-width", $width, "-height", $height, "-halign", "0.5", "-valign", "0.5"]);
    } elsif ( $mimetype eq 'image/tiff' ) {
        $self->_add_step([$Process::Globals::tifftopnm, "-byrow", $filename]);
    } elsif ( $mimetype eq 'image/png' ) {
        # "-alphapam" is needed for going from png+alpha to png+alpha
        $self->_add_step([$Process::Globals::pngtopam, $filename]);
    } elsif ( $mimetype eq 'image/jpeg' ) {
        $self->_add_step([$Process::Globals::jpegtopnm, $filename]);
    } elsif ( $mimetype eq 'image/jp2' ) {
        my @params = (
            "-quiet",
            "-i", $filename,
            "-o", "$Process::Globals::stdout.bmp",
            "-reduce", $self->output->{metadata}->{r},
            "-num_threads", "0",
        );
        if ( $self->rotation > 0 && $self->rotation % 90 == 0 ) {
            push @params, "-rotate", $self->rotation;
        }
        $self->_add_step([
            $Process::Globals::kdu_expand,
            @params,
        ]);
        $self->_add_step([$Process::Globals::bmptopnm]);
    }
}

sub _process_output {
    my $self = shift;
    my $mimetype = $self->output->{mimetype};
    my $xres = $self->output->{metadata}->{XResolution} || $self->source->{metadata}->{XResolution};
    my $yres = $self->output->{metadata}->{YResolution} || $self->source->{metadata}->{YResolution};
    my @cmd;

    if ( $self->quality eq 'gray' ) {
        $self->_add_step(["$Process::Globals::ppmtopgm"]);
    } elsif ( $self->quality eq 'bitonal' ) {
        $self->_add_step(["$Process::Globals::ppmtopgm"]);
        $self->_add_step(["$Process::Globals::pamthreshold"]);
    }

    if ( $mimetype eq 'image/tiff' ) {
        my @args;

        if ( $self->_is_bitonal($self->source->{metadata}) || $self->quality eq 'bitonal' ) {
            $self->_add_step(["$Process::Globals::pamthreshold"]);
            push @args, "-g4";
        } else {
            unless ( $self->_is_grayscale($self->source->{metadata}) ) {
                push @args, '-color';
                push @args, '-truecolor';
            }
            push @args, '-flate';
        }

        $self->_add_step([$Process::Globals::pamtotiff, @args])
    } elsif ( $mimetype eq 'image/png' ) {
        if ( $self->_is_grayscale($self->source->{metadata}) || $self->quality =~ m,gray|bitonal, ) {
            $self->_add_step(["$Process::Globals::ppmtopgm"]);
        }
        ### $self->_add_step(["$Process::Globals::pamrgbatopng"]);
        @cmd = ( "$Process::Globals::pnmtopng", "-compression", 1 );
        if ( $xres && $yres ) {
            # convert in to m
            $xres = ( $xres * 2.54 ) / 100;
            $yres = ( $yres * 2.54 ) / 100;
            $xres = sprintf("%0.0f", $xres);
            $yres = sprintf("%0.0f", $yres);
            push @cmd, "-size", "$xres $yres 1" if ( $xres > 0 && $yres > 0 );
        }
        $self->_add_step(\@cmd);
    } elsif ( $mimetype eq 'image/jpeg' ) {
        if ( $self->restricted ) {
            $self->_add_step(["/l/local/bin/pamtopnm"]);
        }
        @cmd = ( "$Process::Globals::pnmtojpeg", "-quality", 95 );
        unless ( $yres && $xres ) {
            $xres = $yres = 72;
        }
        $xres = sprintf("%0.0f", $xres);
        $yres = sprintf("%0.0f", $yres);
        push @cmd, "-density", "${xres}x${yres}dpi";
        $self->_add_step(\@cmd);
    } elsif ( $mimetype eq 'image/jp2' ) {
        # turn it into a TIFF first
        $self->_add_step([$Process::Globals::pnmtotiff]);
        if ( $self->tmpfilename ) {
            $$self{backuptmpfilename} = $self->tmpfilename;
            $self->tmpfilename($self->tmpfilename . '.tif');
        } else {
            # this needs to go somewhere!
            $self->tmpfilename("/ram/$$.tif");
        }
    }
}

sub _process_sizing {
    my $self = shift;
    my $info = $self->output->{metadata};
    my $scale_cmd;
    return if ( $self->source->{mimetype} eq 'image/jp2' && $$info{exact} );
    return if ( $$info{r} == 0 && $$info{exact} );
    return if ( $self->blank || $self->restricted );

    my $cmd = $Process::Globals::pnmscalefixed;
    # if ( $self->source->{mimetype} eq 'image/png' || $self->restricted ) { $cmd = $Process::Globals::pamscale; }
    if ( $$info{width} && $$info{height} && $$info{do_best_fit} ) {
        $scale_cmd = [$cmd, "-xysize", $$info{width}, $$info{height}];
    } elsif ( $$info{width} && $$info{height} ) {
        # distort
        $scale_cmd = [$cmd, "-xsize", $$info{width}, "-ysize", $$info{height}];
    } elsif ( $$info{width} ) {
        $scale_cmd = [$cmd, "-xsize", $$info{width}];
    } else {
        $scale_cmd = [$cmd, "-ysize", $$info{height}];
    }
    $self->_add_step($scale_cmd);
}

sub _process_region {
    my $self = shift;
    # NOOP
}

sub _process_rotation {
    my $self = shift;
    return if ( $self->source->{mimetype} eq 'image/jp2' && ( $self->rotation % 90 == 0 ) );
    return if ( $self->blank || $self->restricted );
    return if ( $self->rotation == 0 );

    my $rotation = 360 - $self->rotation; # netpbm
    if ( $self->rotation % 90 == 0 ) {
        $self->_add_step([$Process::Globals::pamflip, "-r$rotation" ]);
    } else {
        $rotation = $self->rotation;
        $self->_add_step([$Process::Globals::pnmrotate, "-background", "rgb:ff/ff/ff", $rotation ]);
    }
}

sub _process_watermark {
    my $self = shift;
    return unless ( $self->watermark );
    return unless ( ref($self->mdpItem) );
    return if ( $self->restricted );

    my $suffix = '.png';
    my $is_bw = 0;
    if ( $self->output->{mimetype} eq 'image/tiff' && ( $self->_is_bitonal($self->source->{metadata}) || $self->quality eq 'bitonal' ) ) {
        $suffix = '.bw.png';
        $is_bw = 1;
    }

    my $info = $self->output->{metadata};
    my $mark_width = floor($$info{width} * 0.5 * 0.8);

    my ( $digitized_base, $original_base ) = $self->_get_watermark_filename();
    return unless ( $digitized_base || $original_base );

    my @digitized_dim; my @original_dim;
    my $original_offset_y = 0;
    my $digitized_offset_y = 0;

    my $y_offset = 0;
    if ( $original_base ) {
        @original_dim = imgsize("$original_base$suffix");
        $y_offset = floor($original_dim[1] * 0.25);
    }
    if ( $digitized_base) {
        @digitized_dim = imgsize("$digitized_base$suffix");
        if ( $digitized_dim[1] > $original_dim[1] ) {
            $y_offset = floor($digitized_dim[1] * 0.25);
            $original_offset_y = ( $digitized_dim[1] - $original_dim[1] );
        } else {
            $digitized_offset_y = ( $original_dim[1] - $digitized_dim[1] );
        }
    }

    if ( $digitized_base ) {
        my @args;
        unless ( $is_bw ) {
            push @args, "-alpha", "$digitized_base.pgm", "$digitized_base.pnm";
        } else {
            push @args, "$digitized_base.bw.pnm";
        }
        $self->_add_step([
            $Process::Globals::pamcomp,
            "-valign", "bottom",
            "-align", "center",
            "-yoff", -( $digitized_offset_y + $y_offset ),
            "-xoff", -(int($mark_width / 2) + 5),
            @args,
        ]);
    }

    if ( $original_base ) {
        my @args;
        unless ( $is_bw ) {
            push @args, "-alpha", "$original_base.pgm", "$original_base.pnm";
        } else {
            push @args, "$original_base.bw.pnm";
        }

        $self->_add_step([
            $Process::Globals::pamcomp,
            "-valign", "bottom",
            "-align", "center",
            "-yoff", -( $original_offset_y + $y_offset ),
            "-xoff", (int($mark_width / 2) + 5),
            @args,
        ]);
    }

}

sub _get_watermark_filename {
    my $self = shift;
    my $info = $self->output->{metadata};

    my @filenames = SRV::Utils::get_watermark_filename($self->mdpItem, $info);

    return @filenames;
}

sub _get_watermark_filename_OLD {
    my $self = shift;

    my $watermark_filename = $self->watermark;
    my $info = $self->output->{metadata};
    if ( $Process::Globals::watermark_min_width && $$info{width} <= $Process::Globals::watermark_min_width ) {
        my $target_width = $$info{width} - 5;
        $target_width -= ( $target_width % 5 );
        if ( $target_width <= 0 ) {
            return;
        }

        my $output_filename = $self->output->{pathname} . basename($watermark_filename) . "_" . $target_width;
        unless ( -f "$output_filename.pnm" ) {
            foreach my $ext ( qw/pnm pgm/ ) {
                my $cmd = [ $Process::Globals::pnmscalefixed, "-verbose", "-xsize", $target_width, "$watermark_filename.$ext" ];
                IPC::Run::run $cmd, ">", "$output_filename.$ext";
            }
            $watermark_filename = $output_filename;
        }
    }
    return $watermark_filename;
}

# UTILITY

sub _merge {
    my $self = shift;
    my $hash = shift;
    my $new = shift;
    foreach my $key ( keys %$new ) {
        $$hash{$key} = $$new{$key};
    }
}

sub _get_levels {
    my ( $hash ) = @_;
    my $max = ( $$hash{width} > $$hash{height} ) ? $$hash{width} : $$hash{height};
    my $l = 0;
    while ( $max >= 256 ) {
        $l += 1;
        $max /= 2;
    }
    return $l;
}

sub _get_file_info {
    my $self = shift;
    my $hash = shift;
    my $do_get_metadata = scalar @_ ? shift : 1;
    return unless ( $$hash{filename} );
    my $mime_data = $mimetypes->mimeTypeOf($$hash{filename});
    my @suffixes = map(".$_", @{$$mime_data{MT_extensions}});
    my ( $basename, $pathname, $suffix) = fileparse($$hash{filename}, @suffixes );
    $$hash{basename} = $basename;
    $$hash{pathname} = $pathname;
    $$hash{suffix} = $suffix;
    $$hash{mimetype} = $$mime_data{MT_type};

    if ( -s $$hash{filename} && $do_get_metadata ) {
        my $info;
        $info = Image::Utils::image_info($$hash{filename});
        if ( $$hash{mimetype} eq 'image/jp2' ) {
            $$hash{metadata} = {
                width => $$info{width},
                height => $$info{height},
                colorspace => $$info{ColorSpace},
                XResolution => $$info{XResolution},
                YResolution => $$info{YResolution},
                ResolutionUnit => $$info{ResolutionUnit},
                levels => $$info{levels} || _get_levels($info)
            };
        } else {
            $$hash{metadata} = {
                width => $$info{width},
                height => $$info{height},
                colorspace => $$info{ColorSpace} || '',
                XResolution => $$info{XResolution} ? $$info{XResolution}->as_float : undef,
                YResolution => $$info{YResolution} ? $$info{YResolution}->as_float : undef,
                ResolutionUnit => $$info{ResolutionUnit},
                SamplesPerPixel => $$info{SamplesPerPixel},
                BitsPerSample => $$info{BitsPerSample},
                PhotometricInterpretation => $$info{PhotometricInterpretation},
            };

            $$hash{metadata}{colorspace} = 'Grayscale' 
                if ( ! $$hash{metadata}{colorspace} && $$info{SamplesPerPixel} == 1 && $$hash{metadata}{BitsPerSample} == 1 );

            unless ( $$hash{metadata}{levels} ) {
                $$hash{metadata}{levels} = _get_levels($$hash{metadata});
            }
        }
    }


}

sub _is_grayscale {
    my $self = shift;
    my ( $info ) = @_;
    return $$info{colorspace} && 
        ( $$info{colorspace} eq 'Grayscale' || 
          $$info{colorspace} eq 'sLUM' );
}

sub _is_bitonal {
    my $self = shift;
    my ( $info ) = @_;
    return $$info{SamplesPerPixel} && $$info{SamplesPerPixel} == 1 && 
        $$info{BitsPerSample} && $$info{BitsPerSample} == 1;
}

sub imgsize {
    my $filename = shift;
    my ( $w, $h );
    my $info = Image::Utils::image_info($filename);
    ( $w, $h ) = ( $$info{width}, $$info{height} );
    return ( $w, $h );
}


1;
