package Process::Volume::PDF::EBM;

use parent qw( Process::Volume::PDF );

use File::Basename qw(basename dirname fileparse);
use Image::ExifTool qw(ImageInfo);

sub generate_pdf {
    my $self = shift;
    my ( $env ) = @_;
    
    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $auth = $C->get_object('Auth');

    my %filemap = $self->_gather_files($mdpItem);
        
    my $updater = $self->updater;
    $updater->initialize;

    # set PDF information
    $self->output_document->info(
        'Title' => $mdpItem->GetFullTitle(1),
        'Author' => $mdpItem->GetAuthor(1),
        'CreationDate' => $self->creation_date(),
        'Creator' => qq{HathiTrust},
        'Producer' => qq{HathiTrust Image Server / PDF::API3}
    );
    
    $ps_ref = $self->get_adjusted_page_size();
    my ($x1, $y1, $x2, $y2) = @$ps_ref;
    my ($w, $h) = ($x2, $y2);
    
    my ($center_x, $center_y, $wm_margin_y);
    ($center_x, $center_y) = ($x2 / 2, $y2 / 2);

    my $i = 0; my $processor;
    foreach my $seq ( @{ $self->pages } ) {
        
        $i += 1;

        my $extract_filename = $filemap{$seq};
        next unless ( $extract_filename );

        die "PDF CANCELLED" if ( $updater->is_cancelled );

        $updater->update($i);
        
        my %page_features = map { $_ => 1 } $mdpItem->GetPageFeatures($seq);

        if ( $page_features{FRONT_COVER} || 
             $page_features{BACK_COVER} || 
             $page_features{CHECKOUT_PAGE} || 
             $page_features{MISSING_PAGE} ) {
            my $page = $self->output_document->page();
            $page->mediabox($x1, $y1, $x2, $y2);
            next;
        }

        my ( $base_filename, $path, $suffix ) = fileparse($extract_filename, '.jp2', '.tif', '.jpg');
        
        my $input_dir = $mdpItem->GetDirPathMaybeExtract([ "$path$base_filename$suffix", "$path$base_filename.txt" ]);
        
        my $image_filename = $input_dir . "/" . $base_filename . $suffix;

        my $targetPPI = 0;
        if ( $self->target_ppi > 0 ) {
            $targetPPI = $self->target_ppi;
        } else {
            my $file_size = ( -s $image_filename );
            if ( $do_downsampling || $file_size >= (1024 * 1024) ) {
                # reduce PPI for files > 1MB
                $targetPPI = 150;
                if ( $file_size > ( 10 * 1024 * 1024 ) ) {
                    # reduce PPI further for files > 10MB
                    $targetPPI = 75;
                }
            }
        }
        
        my $info = ImageInfo($image_filename);
        my $res = $$info{XResolution};

        if ( $image_filename =~ m!\.jp2! || $targetPPI > 0 ) {
            # convert JP2 to JPEG
            # alter filename in case source image is also JPEG
            
            my $output_format = 'png';
            
            my $tmp_filename = qq{$input_dir/$base_filename-$$.$output_format};

            $processor = new Process::Image;
            $processor->source( filename => $image_filename );
            $processor->output( filename => $tmp_filename );
            $processor->format("image/png");
            $processor->size("res:1");
            $processor->quality('grey');
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

        my $page = $self->output_document->page();
        
        # do it again
        $info = ImageInfo($image_filename);
        my ( $image_w, $image_h ) = ( $$info{ImageWidth}, $$info{ImageHeight} );
        
        if ( $image_w > $image_h ) {
            # landscape page, so rotate
            ( $x2, $y2 ) = ( $ps_ref->[3], $ps_ref->[2] );
            ($center_x, $center_y) = ($x2 / 2, $y2 / 2);

            if ( $seq % 2 == 1 ) {
                # odd sequence, so ... recto
                $page->rotate(-90);
            } else {
                $page->rotate(90);
            }
        } else {
            # recalculate coordinates
            ($x1, $y1, $x2, $y2) = ($ps_ref->[0], $ps_ref->[1], $ps_ref->[2], $ps_ref->[3]);
            ($center_x, $center_y) = ($x2 / 2, $y2 / 2);
        }

        print STDERR "PAGE DIMENSIONS: $image_filename : $x2 x $y2\n";
        
        $page->mediabox($x1, $y1, $x2, $y2);
        
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
            $image_data = $self->output_document->image_tiff($image_filename);
        }

        my $r; my $max;

        ( $image_w, $image_h ) = $self->adjust_dimensions($image_w, $image_h, $x2, $y2);

        my $image = $page->gfx;
        my $xpos = ( $center_x - ( $image_w / 2 ) );
        my $ypos = ( $center_y - ( $image_h / 2 ) );
        
        eval {
            $image->image($image_data, $xpos, $ypos, $image_w, $image_h);
        };
        if ( my $err = $@ ) {
            die "COULD NOT ADD IMAGE : $image_filename : $seq\n\n$err";
        }

        eval {
            $self->output_document->stream_content;
        };
        if ( my $err = $@ ) {
            die "PDF ERROR :: $image_filename :: $seq\n\n$err";
        }
                
        IPC::Run::run([ "/bin/rm", "-rf", $input_dir]);
        last if ( $limit && $seq >= $limit );
        
    }

    if ( scalar @{ $self->pages } > 1 ) {
        # don't bother with the cover page if we're just 
        # printing one PDF
        $self->insert_colophon_page(scalar @{ $self->pages } + 1);
    }
    
    $updater->finish();

    return 1;
    
}

sub get_margin {
    my $self = shift;
    return ( 1 * ( 0.8 * 72 ) );
    # return ( 2 * ( 0.8 * 72 ) );
}

sub get_adjusted_page_size {
    my $self = shift;
    my ( $width, $height ) = @_;

    return [ 0, 0, ( 6 * 72 ) , ( 9 * 72 ) ];
    
    # my $margin = 0.8 * 72;
    # return [ 0, 0, ( $width * 72 ) + ( 2 * $margin ) , ( $height * 72 ) + ( 2 * $margin ) ];
}


1;