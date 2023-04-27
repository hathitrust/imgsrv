package Process::Volume::PDF;

use Plack::Util;
use Plack::Util::Accessor qw(
    output_filename
    output_document
    working_path
    mdpItem
    marker
    restricted
    rotation
    limit
    target_ppi
    quality
    max_dim
    pages
    total_pages
    is_partial
    searchable
    output_fh
    updater
    streaming
    stamper
);

use PDF::API2;
require PDF::API2::_patches;

use Image::ExifTool;
use Image::Utils;

use SRV::Utils;
use Process::Globals;

use Process::Image;

use File::Basename qw(basename dirname fileparse);
use Data::Dumper;
use List::MoreUtils qw(any);
use POSIX qw(strftime ceil);
use Time::HiRes;

use Debug::DUtils;

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

sub process {
    my $self = shift;
    my $env = shift;

    $$self{start_time} = Time::HiRes::time();
    $$self{streaming} = defined $self->streaming ? $self->streaming : 1;

    # will need to so something different for status
    unless ( ref $self->output_filename ) {
        $self->output_fh(new IO::File $self->output_filename . ".download", "w");
    } else {
        $self->output_fh($self->output_filename);
    }

    local $ENV{__debug_jpeg2000_exif} = $$env{__debug_jpeg2000_exif};
    local $ENV{__debug_coordocr} = ( $$env{DEBUG} =~ m,coordocr, );

    my $output_document = PDF::API2->new(-file => $self->output_fh);
    $$output_document{forcecompress} = 0;
    $self->output_document($output_document);

    $self->output_document->mediabox('Letter');

    if ( $self->restricted ) {
        $self->generate_restricted_pdf($env);
    } else {
        $self->generate_pdf($env);
    }

    eval {
        $self->output_document->save();
    };
    if ( my $err = $@ ) {
        die "COULD NOT SAVE PDF: $err";
    }

    # and then rename the output_file
    if ( -f $self->output_filename . ".download" ) {
        rename($self->output_filename . ".download", $self->output_filename);
    }

    return {
        filename => $self->output_filename,
        mimetype => "application/pdf"
    };
}

sub generate_restricted_pdf {
    my $self = shift;
    my ( $env ) = @_;

    my $rotation = $self->{rotation};
    my $page = $self->output_document->page();
    my ($x0, $y0, $x1, $y1) = $page->get_mediabox;

    my $text_rotation = 0;
    if ( $rotation ) {
        $page->rotate($rotation);
        $text_rotation = abs(-$rotation);
    }

    my $gfx = $page->gfx;

    $gfx->fillcolor('#000');
    $gfx->rectxy($x0,$y0,$x1,$y1);
    $gfx->fillstroke;

    my $font = $self->get_font();
    my ($center_x, $center_y) = ($x1/2, $y1/2);
    $gfx->textlabel($center_x, $center_y, $font, 36, "restricted", -color => '#FFF', -hspace=>125,-center=>1,-rotate=>$text_rotation);

}

sub generate_pdf {
    my $self = shift;
    my ( $env ) = @_;

    my $mdpItem = $self->mdpItem;

    my $egstate = $self->output_document->egstate;
    $egstate->strokealpha(0.0125);
    $egstate->transparency(1);
    $$self{egstate} = $egstate;

    # capture the image filenames
    my %filemap = $self->_gather_files($mdpItem);

    if ( $self->searchable ) {
        # don't embed this if we're not embedding OCR text
        my $lang = $mdpItem->GetLanguage();
        if ( any { $_ eq $lang } @Process::Globals::gNonWesternLanguages ) {
            $$self{ocrfont} = $self->get_font('unifont-6.3.20131020.ttf');
            $$self{ocrfontname} = q{unifont-6.3.20131020.ttf};
        } else {
            # use the default font
            # $$self{ocrfont} = $$self{font};
            $$self{ocrfont} = $self->get_font();
            $$self{ocrfontname} = q{DejaVuSans.ttf};
        }
    }

    # set PDF information
    $self->output_document->info(
        'Title' => $mdpItem->GetFullTitle(1),
        'Author' => $mdpItem->GetAuthor(1),
        'CreationDate' => $self->creation_date(),
        'Creator' => qq{HathiTrust},
        'Producer' => qq{HathiTrust Image Server / PDF::API2}
    );

    my $updater = $self->updater;

    my $ocmd = $self->output_document->add_optional_content_group("Watermark");
    my $stamp = $self->output_document->importPageIntoForm($self->stamper->document, 2);
    $$stamp{OC} = $ocmd;

    $$self{readingOrder} = $mdpItem->Get('readingOrder');

    my $searchable = $self->searchable;

    my $rotation = $self->rotation;

    my $feature_map = $self->get_feature_map;
    my $outline_items = [];

    my $seq = 0; my $processor;

    # find the total size of this PDF if we use the source images
    my $total_pdf_size = 0;

    foreach my $seq ( @{ $self->pages } ) {
        my $extract_filename = $filemap{$seq};
        next unless ( $extract_filename );

        $total_pdf_size += $mdpItem->GetFileSizeBySequence($seq, 'imagefile');
    }

    my $do_downsampling = 0;
    my $MAX_PDF_SIZE = 1.5 * ( 1024 ** 3);
    if ( $total_pdf_size > $MAX_PDF_SIZE ) {
        $do_downsampling = 1;
    }

    my $i = 0; my $t0 = Time::HiRes::time();
    foreach my $seq ( @{ $self->pages } ) {
        $i += 1;

        my $extract_filename = $filemap{$seq};
        next unless ( $extract_filename );

        if ( $i % 50 == 0 ) {
            print STDERR "PROCESSING : $seq : $extract_filename\n";
        }

        die "PDF CANCELLED" if ( $updater->is_cancelled );

        $updater->update($i);

        my $coord_ocr_filename = $mdpItem->GetFileNameBySequence($seq, 'coordOCRfile');
        my $ocr_filename = $mdpItem->GetFileNameBySequence($seq, 'ocrfile');

        # print STDERR "== processing: $extract_filename\n";
        my ( $base_filename, $path, $suffix ) = fileparse($extract_filename, '.jp2', '.tif', '.jpg');
        my @extract = ();
        push @extract, "$path$base_filename$suffix" unless ( grep(/MISSING_PAGE/, $mdpItem->GetPageFeatures($seq)) );
        if ( $coord_ocr_filename ) { push @extract, "$path$coord_ocr_filename" ; }
        if ( $ocr_filename ) { push @extract, "$path$ocr_filename" ; }
        my $input_dir = $mdpItem->GetDirPathMaybeExtract(\@extract);
        my $image_filename = $input_dir . "/" . $base_filename . $suffix;
        if ( grep(/MISSING_PAGE/, $mdpItem->GetPageFeatures($seq)) ) {
            $image_filename = $SRV::Globals::gMissingPageImage;
        }

        $ocr_filename = $input_dir . "/" . $ocr_filename if ( $ocr_filename );
        $coord_ocr_filename = $input_dir . "/" . $coord_ocr_filename if ( $coord_ocr_filename );

        my $targetPPI = 0;
        if ( $self->target_ppi > 0 ) {
            $targetPPI = $self->target_ppi;
        } else {
            my $file_size = ( -s $image_filename );
            if ( $do_downsampling || $file_size >= ( 1024 * 1024 * 1.5 ) ) {
                # reduce PPI for files > 1MB
                $targetPPI = 150;
                if ( $file_size > ( 10 * 1024 * 1024 ) ) {
                    # reduce PPI further for files > 10MB
                    $targetPPI = 75;
                }
            }
        }
        # ignore targetPPI/quality for TIFF; source best addresses quality and file size
        my $ignore_transforms = ( $image_filename =~ m,\.tif, );

        my $page = $self->output_document->page();

        my $info = Image::ExifTool::ImageInfo($image_filename);
        my ( $image_w, $image_h ) = ( $$info{ImageWidth}, $$info{ImageHeight} );

        my ( $page_width, $page_height ) = Image::Utils::page_dim($info);

        # increase page width to account for the stamp
        $page_width += $self->stamper->marginalia_width;
        $page_height += $self->stamper->watermark_height;
        $page->mediabox(0, 0, $page_width, $page_height );
        my @mediabox = $page->get_mediabox;

        my ( $x1, $y1, $x2, $y2, $center_x, $center_y );

        if ( $image_w > $image_h ) {
            # landscape page...
            ( $x1, $y1 ) = ( 0, 0 );
            ( $x2, $y2 ) = ( $mediabox[3], $mediabox[2] ); 
            ($center_x, $center_y) = ($x2 / 2, $y2 / 2);
            $page->mediabox($x1, $y1, $x2, $y2);
        } else {
            # recalculate coordinates
            ($x1, $y1, $x2, $y2) = (@mediabox);
            ($center_x, $center_y) = ($x2 / 2, $y2 / 2);
        }

        $center_x += $self->stamper->marginalia_width;

        if ( $rotation ) {
            $page->rotate($rotation);
        }

        ## targetPPI or quality require transforming the source image
        if ( ! $ignore_transforms && ( $targetPPI > 0 || $self->quality ne 'default' ) ) {

            my $output_format = 'jpg';
            if ( $self->quality eq 'bitonal' ) {
                $output_format = 'tif';
            } elsif ( $image_filename =~ m,\.jp2, ) {
                $output_format = 'jp2';
            }
            my $tmp_filename = qq{$input_dir/$base_filename-$$.$output_format};;

            $processor = new Process::Image;
            $processor->source( filename => $image_filename );
            $processor->output( filename => $tmp_filename );
            $processor->format($output_format);
            $processor->size("ppi:$targetPPI") if ( $targetPPI > 0 );
            $processor->quality($self->quality);

            $processor->max_dim($self->max_dim) if ( $self->max_dim );
            $processor->transformers( $$env{'psgix.image.transformers'} ) if ( defined $$env{'psgix.image.transformers'} );
            $processor->logfile("$input_dir/process.log");

            my $efi_hr = $processor->process();
            unlink($image_filename);
            $image_filename = $tmp_filename;

            unless ( -f $image_filename ) {
                die "PDF Generation Failed: $image_filename\n";
            }
        }

        my $image;
        if ( grep(/CHECKOUT_PAGE/, $mdpItem->GetPageFeatures($seq)) ) {
            # do nothing for now
            $image = $page->gfx;
        } else {
            # normal image processing

            $image = $page->gfx if ( 1 || $ENV{__debug_coordocr} );

            my $image_data;
            if ($image_filename =~ m,\.jp2$,o) {
                $image_data = $self->output_document->image_jp2($image_filename);
            }
            elsif ($image_filename =~ m,\.jpg$,o) {
                $image_data = $self->output_document->image_jpeg($image_filename);
            }
            elsif ($image_filename =~ m,\.png$,o) {
                $image_data = $self->output_document->image_png($image_filename);
            }
            else {
                eval {
                    $image_data = $self->output_document->image_tiff($image_filename);
                };
                if ( my $error = $@ ) {
                    ## print STDERR "AHOY PROBLEM WITH $image_filename : $error\n"; exit;

                    # convert the TIFF to a different TIFF and reload
                    my $tmp_filename = qq{$input_dir/$base_filename-$$.png};
                    $processor = new Process::Image;
                    $processor->source( filename => $image_filename );
                    $processor->output( filename => $tmp_filename );
                    $processor->size("full");
                    $processor->format("image/png");
                    $processor->quality('gray');
                    $processor->max_dim($self->max_dim) if ( $self->max_dim );
                    $processor->logfile("$input_dir/process.log");
                    my $efi_hr = $processor->process();

                    $image_filename = $tmp_filename;
                    $image_data = $self->output_document->image_png($image_filename);
                }
            }

            my $r; my $max; my $ratio;

            my $original_h; my $original_w;
            $original_w = $image_w = $image_data->width;
            $original_h = $image_h = $image_data->height;
            ( $image_w, $image_h, $ratio) = $self->adjust_dimensions(
                $image_w, $image_h, 
                $x2 - $self->stamper->marginalia_width, 
                $y2 - $self->stamper->watermark_height);

            my $xpos = $self->stamper->marginalia_width;
            my $ypos = $self->stamper->watermark_height;

            if ($searchable) {
                require Process::Volume::Utils;
                my $data;
                my $err;

                eval {
                    if ( $coord_ocr_filename ) {
                        $data = Process::Volume::Utils::get_text_coordinates($coord_ocr_filename);
                    }
                };

                if ( $err = $@ ) {
                    SRV::Utils::log_message("OCR: COULD NOT LOAD COORDINATE : $coord_ocr_filename : $seq\n\n$err");
                }

                eval {
                    unless ( ref($data) ) {
                        $data = Process::Volume::Utils::get_text_lines($ocr_filename);
                    };
                };

                if ( $err = $@ ) {
                    SRV::Utils::log_message("OCR: COULD NOT LOAD PLAIN TEXT : $ocr_filename : $seq\n\n$err");
                }

                eval {
                    if ( $$data{uses_coordinates} ) {
                        $self->insert_text_as_coordinates($page, $data, $original_w, $original_h, $xpos, $ypos, $ratio );
                    } else {
                        $self->insert_text_as_lines($page, $data, $y2);
                    }
                };

                if ( $err = $@ ) {
                    SRV::Utils::log_message("COULD NOT ADD TEXT : $ocr_filename : $seq\n\n$err");

                }
            }

            $image = $page->gfx unless ( defined $image );
            eval {
                $image->image($image_data, $xpos, $ypos, $image_w, $image_h);
            };
            if ( my $err = $@ ) {
                die "COULD NOT ADD IMAGE : $image_filename : $seq\n\n$err";
            }
        }

        eval {
            $self->output_document->stream_content if ( 1 || $$self{streaming} );
        };
        if ( my $err = $@ ) {
            die "PDF ERROR :: $image_filename :: $seq\n\n$err";
        }


        $self->insert_watermark($page, $stamp);

        if ( $$feature_map{$seq} ) {
            my ( $label, $page_num ) = @{ $$feature_map{$seq} };
            $label = "$label (Page $page_num)" if ( $page_num );
            push @$outline_items, [ $label, $page ];
        }

        IPC::Run::run([ "/bin/rm", "-rf", $input_dir]);

        unless ( $self->is_partial ) {
            my $t1 = Time::HiRes::time();
            print STDERR join(" : ", $seq, $extract_filename, $t1 - $t0) . "\n";
            $t0 = $t1;
        }
    }


    $self->insert_colophon_page() if ( ! $ENV{__debug_coordocr} && scalar @{ $self->pages } > 1 );
    $self->insert_outline($outline_items) if ( scalar @$outline_items );

    $updater->finish();

    return 1;

}

# ---------------------------------------------------------------------

sub _gather_files {
    my $self = shift;
    my $mdpItem = shift;

    my $limit = $self->limit || 0;
    my @pages = ref($self->pages) ? @{ $self->pages } : ();

    unless ( scalar @pages ) {
        my $pageinfo_sequence = $mdpItem->Get('pageinfo')->{'sequence'};
        @pages = sort { int($a) <=> int($b) } keys %{ $pageinfo_sequence };
    }

    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($mdpItem->GetId());
    my $total_items = $limit || scalar @pages;

    # capture the image filenames
    my %filemap = ();
    foreach my $seq ( @pages ) {
        my $image_filename = $mdpItem->GetFileNameBySequence($seq, 'imagefile');
        # next unless ( $image_filename );
        unless ( $image_filename ) {            
            my $ocr_filename = $mdpItem->GetFileNameBySequence($seq, 'ocrfile');
            next unless ( $ocr_filename );

            if ( ! defined $mdpItem->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'} ) {
                $mdpItem->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'} = [];
            }
            push @{ $mdpItem->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'} }, 'MISSING_PAGE';
            $image_filename = basename($ocr_filename, '.txt') . '.jp2';
        }
        $image_filename = "$stripped_pairtree_id/$image_filename";
        $filemap{$seq} = $image_filename;
    }

    $self->pages(\@pages);
    $$self{total_pages} = scalar @pages;

    return %filemap;
}

sub insert_text_as_coordinates {
    my $self = shift;
    my ( $page, $data, $width, $height, $xpos, $ypos, $ratio ) = @_;

    my %fonts = {};
    $fonts{'Helvetica'} = $$self{ocrfont};

    my $fillcolor; my $strokecolor;
    $fillcolor = q{#ffffff};
    $fillcolor = q{#ff000000} if ( $ENV{__debug_coordocr} );
    # $fillcolor = q{rgba(255,255,255,0.00125)};

    $strokecolor = '#000000';
    # $strokecolor = q{#ffffff};

    my $text_width = $$data{width};
    my $text_height = $$data{height};

    $text_height = $height unless ( $text_height );

    my $scale_up = 1.0; # $width / $px1;

    my $r = ( $height / $text_height ); my $r1 = $r;
    $r *= $ratio;

    my $margin_top = $ypos + ( $height * $ratio );

    $page->gfx()->save;

    my $txt = $page->text;
    $txt->egstate($$self{egstate});
    $txt->textstart;
    $txt->fillcolor($fillcolor);
    $txt->strokecolor($strokecolor);

    my $gfx = $page->gfx;
    # $gfx->strokecolor(q{#CCCCCC});

    my $last_font_size = -1; my $have_been_rotating = 0;

    foreach my $word ( @{ $$data{words}} ) {
        my $font_size = 6;
        my $font_size_1 = $font_size;
        my $word_font = $fonts{Helvetica};

        my $box_width = $$word{width} * $r;
        my $top = $$word{top};

        my $aw;

        my $debug_font_name = $word_font->fontname;
        # my $next_font_size = $font_size;
        # while ( ( $aw = $txt->advancewidth($$word{content}, font => $word_font, fontsize => $next_font_size) ) < $box_width ) {
        #     ## print STDERR "FIDDLING : $aw / $box_width / $font_size / $debug_font_name / $$word{content}\n" if ( $debug_fiddle );
        #     last unless ( $aw );
        #     $font_size = $next_font_size;
        #     $next_font_size += 1;
        # }

        $font_size = $txt->bestfitfontsize($$word{content}, font => $word_font, box_width => $box_width);

        if ( $last_font_size != $font_size ) {
            $txt->font($word_font, $font_size);
            $last_font_size = $font_size;
        }

        # y coordinate is a delta from the margin top (0 == bottom), minus the height
        my $word_height = $$word{height} * $r;
        my $y1a = $margin_top - ( $top * $r ) - ( $$word{height} * $r );

        my $y1b = $y1a;
        if ( $$word{content} =~ m{g|j|p|q|y|,|;} ) {
            # HACK? tweak position of word to account for descender??
            $y1b += ( $font_size * 1.2 - $font_size );
        }

        my $x1a = ( $$word{left} * $r );
        # $txt->translate( $xpos + $x1a, $y1b );
        my $rotate = 0; my $delta_x = 0;
        if ( $$word{width} < $$word{height} ) {
            if ( length($$word{content}) > 2 || $have_been_rotating ) {
                # rotate?
                $rotate = 90;
                $delta_x = $$word{width} * $r;
                $have_been_rotating = 1;
            }
        }

        if ( $ENV{__debug_coordocr} ) {
            $gfx->rect($xpos + $x1a, $y1a, $box_width, $$word{height} * $r);
            $gfx->stroke();
        }


        $txt->transform(-translate => [$xpos + $x1a + $delta_x, $y1b], -rotate => $rotate);

        my $actual_height = abs($font_size - $word_height);
        my $actual_width = $txt->text($$word{content});

        if ( 0 && $ENV{__debug_coordocr} ) {
            print STDERR join(" : ", "WORD", $x1a, $top * $r, $$word{left}, $$word{top}, $aw, $actual_width, $font_size, $$word{content}) . "\n";
        }
    }

    $txt->textend;
    $page->gfx()->restore();

}

sub insert_text_as_lines {
    my $self = shift;
    my ($page, $data, $h) = @_;
    my $font = $$self{ocrfont};

    if (scalar @{ $$data{lines} }) {

        # start 12% lower than top of page
        my $y = $h - (0.12 * $h);
        $page->gfx()->save;
        my $txt = $page->text;
        $txt->egstate($$self{egstate});
        $txt->font($font, 4);
        $txt->fillcolor('#ffffff');
        $txt->translate(10,$y);
        foreach my $txt_data ( @{ $$data{lines} } ) {
            next if ( $txt_data =~ m!^\s*$! );
            $txt_data =~ s!^\s*!!gsm; $txt_data =~ s!\s*$!!gsm;
            if ( $$self{readingOrder} eq 'right-to-left' ) {
                utf8::decode($txt_data);
                $txt_data = join '', reverse $txt_data =~ m/\X/g;
            }
            $txt->text($txt_data);
            $txt->cr(-10);
        }
        $page->gfx()->restore();
    }
}

sub insert_watermark {
    my $self = shift;
    my ( $page, $stamp ) = @_;
    my $gfx = $page->gfx;

    my $s = 1.0;
    my @page_mediabox = $page->get_mediabox();
    my @stamp_mediabox = @{ $self->get_page_size('Letter') };

    if ( $page_mediabox[2] != $stamp_mediabox[2] ) {
        $s = $page_mediabox[2] / $stamp_mediabox[2];
    }

    # $gfx->artifactStart('OC', $ocmd);
    $gfx->formimage($stamp, 0, 0, $s);
    # $gfx->artifactEnd;

}

sub insert_colophon_page {
    my $self = shift;
    my $page_num = shift || 1;
    $self->output_document->import_page($self->stamper->document, 1, $page_num);
}

sub insert_outline {
    my $self = shift;
    my $outline_items = shift;
    my $outlines = $self->output_document->outlines;
    foreach my $item ( @$outline_items ) {
        my ( $label, $page ) = @{ $item };
        my $outline = $outlines->outline;
        $outline->title($label);
        $outline->dest($page);
    }
}

sub get_font {
    my $self = shift;
    my $font_name = shift || 'DejaVuSans.ttf';
    unless ( $$self{font} ) {
        $$self{font} = $self->output_document->ttfont($font_name, -encode => 'utf8', -unicodemap => 1);
    }
    return $$self{font};
}

sub get_page_size {
    my $self = shift;
    my $name = shift;

    my %pagesizes =
        (
         'A0'         => [ 0, 0, 2380, 3368 ],
         'A1'         => [ 0, 0, 1684, 2380 ],
         'A2'         => [ 0, 0, 1190, 1684 ],
         'A3'         => [ 0, 0, 842,  1190 ],
         'A4'         => [ 0, 0, 595,  842  ],
         'A4L'        => [ 0, 0, 842,  595  ],
         'A5'         => [ 0, 0, 421,  595  ],
         'A6'         => [ 0, 0, 297,  421  ],
         'LETTER'     => [ 0, 0, 612,  792  ],
         'LETTERL'    => [ 0, 0, 792,  612  ],
         'BROADSHEET' => [ 0, 0, 1296, 1584 ],
         'LEDGER'     => [ 0, 0, 1224, 792  ],
         'TABLOID'    => [ 0, 0, 792,  1224 ],
         'LEGAL'      => [ 0, 0, 612,  1008 ],
         'EXECUTIVE'  => [ 0, 0, 522,  756  ],
         '36X36'      => [ 0, 0, 2592, 2592 ],
        );

    if (! $pagesizes{uc($name)}) {
        $name = 'LETTER';
    }

    return $pagesizes{uc($name)};
}

sub creation_date {
    my $self = shift;
    my @now = gmtime;
    return sprintf "D:%4u%0.2u%0.2u%0.2u%0.2u%0.2u",
        $now[5] + 1900, $now[4] + 1,
        $now[3], $now[2],
        $now[1], $now[0];
}

# ---------------------------------------------------------------------

=item adjust_dimensions

Fit image onto page, which may involve scaling
to fit both width and height.

=cut

# ---------------------------------------------------------------------
sub adjust_dimensions {
    my $self = shift;
    my ( $image_w, $image_h, $x2, $y2 ) = @_;

    my ( $x_image_w, $x_image_h, $x_x2, $x_y2 ) = @_;

    # shrink the dimensions to give the
    # image some margins
    # $x2 -= $self->get_margin();
    # $y2 -= $self->get_margin();

    my $ratio;

    if ( $image_w > $image_h ) {
        $ratio = $x2 / $image_w;
    } else {
        $ratio = $y2 / $image_h;
    }
    $image_w = $image_w * $ratio;
    $image_h = $image_h * $ratio;

    if ( $image_w > $x2 ) {
        $image_h *= ( $x2 / $image_w );
        $image_w = $x2;
    } elsif ( $image_h > $y2 ) {
        $image_w *= ( $y2 / $image_h );
        $image_h = $y2;
    }

    return ( $image_w, $image_h, $ratio );
}

sub get_margin {
    my $self = shift;
    return 50;
}

sub get_feature_map {
    my $self = shift;
    my $mdpItem = $self->mdpItem;
    return SRV::Utils::get_feature_map($mdpItem);
}


# hack

sub round {
  $_[0] > 0 ? int($_[0] + .5) : -int(-$_[0] + .5)
}

1;
