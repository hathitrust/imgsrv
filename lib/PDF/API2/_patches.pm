{
    package PDF::API2;

    our %STREAM_TYPES = ();
    $STREAM_TYPES{'PDF::API2::Resource::XObject::Image::JPEG2000'} = 1;
    $STREAM_TYPES{'PDF::API2::Resource::XObject::Image::TIFF'} = 1;
    $STREAM_TYPES{'PDF::API2::Resource::XObject::Image::JPEG'} = 1;
    sub stream_content {
        my($self) = shift;
        my ( $do_everything ) = ( @_ );
        if ( $self->{' filed'}) {

            while(1) {
                my @objs = ();
                foreach my $obj ( @{ $self->{pdf}->{' outlist'} } ) {
                    my $cls = ref($obj);
                    next unless ( $STREAM_TYPES{$cls} );
                    push @objs, $obj;
                }
                last unless ( scalar @objs );
                $self->{pdf}->ship_out(@objs);
            }
        }
    }

    sub image_jp2 {
        my ($self,$file,%opts)=@_;

        require PDF::API2::Resource::XObject::Image::JPEG2000;
        my $obj=PDF::API2::Resource::XObject::Image::JPEG2000->new_api($self,$file);
        $self->{pdf}->out_obj($self->{pages});
        return($obj);
    }

    sub add_optional_content_group {
        my ($self, $name) = @_;

        my $catalog = $self->{catalog};
        my $properties = PDFDict();
        $self->{pdf}->new_obj($properties);
        $catalog->{'OCProperties'} = $properties;
        my $ocg = PDFDict();
        $self->{pdf}->new_obj($ocg);
        $$ocg{Type} = PDFName('OCG');
        $$ocg{Name} = PDFStr('Watermark'); # exposes layer in layer list
        $$ocg{Intent} = PDFName('Design');
        $$ocg{Usage} = PDFDict();
        $$ocg{Usage}{View} = PDFDict();
        $$ocg{Usage}{PageElement} = PDFDict();
        $$ocg{Usage}{Export} = PDFDict();
        $$ocg{Usage}{Print} = PDFDict();
        $$ocg{Usage}{Print}{PrintState} = PDFName('ON');
        $$ocg{Usage}{Export}{ExportState} = PDFName('ON');
        $$ocg{Usage}{PageElement}{Subtype} = PDFName('FG');

        $$properties{OCGs} = PDFArray();
        $$properties{OCGs}->add_elements($ocg);

        my $d = PDFDict();
        $self->{pdf}->new_obj($d);
        $$properties{D} = $d;

        $$d{Order} = PDFArray();
        $$d{Order}->add_elements($ocg);
        $$d{Locked} = PDFArray();
        $$d{Locked}->add_elements($ocg);
        $$d{AS} = PDFArray();
        my $as_item = PDFDict();
        $$as_item{Category} = PDFArray();
        $$as_item{Category}->add_elements(PDFName('View'));
        $$as_item{Event} = PDFName('View');
        $$as_item{OCGs} = PDFArray();
        $$as_item{OCGs}->add_elements($ocg);
        $$d{AS}->add_elements($as_item);

        $as_item = PDFDict();
        $$as_item{Category} = PDFArray();
        $$as_item{Category}->add_elements(PDFName('Print'));
        $$as_item{Event} = PDFName('Print');
        $$as_item{OCGs} = PDFArray();
        $$as_item{OCGs}->add_elements($ocg);
        $$d{AS}->add_elements($as_item);

        $as_item = PDFDict();
        $$as_item{Category} = PDFArray();
        $$as_item{Category}->add_elements(PDFName('Export'));
        $$as_item{Event} = PDFName('Export');
        $$as_item{OCGs} = PDFArray();
        $$as_item{OCGs}->add_elements($ocg);
        $$d{AS}->add_elements($as_item);

        my $ocmd = PDFDict();
        $self->{pdf}->new_obj($ocmd);
        $$ocmd{Type} = PDFName('OCMD');
        $$ocmd{OCGs} = $ocg;
        return $ocmd;
    }


}

{

    package PDF::API2::Content;

    sub _rotate {
        # RRE - set very small numbers to 0; Perl returns scientific notation when 
        # calculating 90 degrees, which chokes the PDF.
        my ($a)=@_;
        my @values = (cos(deg2rad($a)), sin(deg2rad($a)),-sin(deg2rad($a)), cos(deg2rad($a)),0,0);
        foreach ( @values ) {
            if ( abs($_) < 0.000000000001 ) {
                $_ = 0;
            }
        }
        return @values;
    }

    sub bestfitfontsize {
        my ($self,$text,@opts)=@_;
        if(scalar @opts > 1)
        {
            my %opts=@opts;
            foreach my $k (qw[ font fontsize wordspace charspace hspace])
            {
                $opts{$k}=$self->{" $k"} unless(defined $opts{$k});
            }
            my $advance=$opts{font}->bestfitwidth($text, $opts{box_width}, $opts{hspace}); # *$opts{fontsize};
            #my $advance=($glyph_width)*$opts{hspace}/100;
            return $advance;
        }
    }

    sub artifactStart {
        my $self = shift @_;
        my $obj = shift @_;
        $self->add('/Artifact << /Subtype /Watermark /Type /Pagination >>');
        if (defined $obj) {
            $self->add('BDC');
        }
        else {
            $self->add('BMC');
        }
        return $self;
    }

    sub artifactEnd {
        my $self = shift @_;
        $self->metaEnd;
        return $self;
    }

    sub write_justified_text {
        my $self = shift @_;
        my ( $text, $width ) = @_;
        chomp($text);
        # $self->font($font, $font_size);
        # $self->lead($font_size *1.25);
        # $self->fillcolor('#000000');

        my $toprint;

        while($text ne '') {
            ($toprint, $text) = $self->text_fill_justified($text, $width);
            $self->nl;
        }
    }

}

{
    package PDF::API2::Resource::CIDFont;

    sub bestfitwidth
    {
        my ($self,$text,$box_width,$hspace)=@_;
        my $utext = $self->cidsByStr($text);
        my @uarray = unpack('n*', $utext);
        my $font_size = 6;
        my $next_font_size = $font_size;
        while( ( my $glyph_width = $self->width_cid_array(@uarray) * $next_font_size )  < $box_width ) {
            last if ( $glyph_width == 0 );
            # my $check_glyph_width = $self->width($text) * $font_size;
            $font_size = $next_font_size;
            $next_font_size += 1;
            # print STDERR "BEST FIT $font_size : $glyph_width : $check_glyph_width : $box_width\n";
        }
        return $font_size;
    }

    sub width_cid_array
    {
        my ($self,@textarray)=@_;
        my $width=0;
        my $lastglyph=0;
        foreach my $n (@textarray) 
        {
            $width+=$self->wxByCId($n);
            if($self->{-dokern} && $self->haveKernPairs())
            {
                if($self->kernPairCid($lastglyph, $n))
                {
                    $width-=$self->kernPairCid($lastglyph, $n);
                }
            }
            $lastglyph=$n;                    
        }
        $width/=1000;
        return($width);
    }
}

{
    package PDF::API2::Resource::CIDFont::TrueTypeXXX;

    sub _map 
    {
        my $self = shift;
        my @refs = @_;
        foreach my $_g ( @refs ) {
            if ( ref($_g) ) {
                $self->_map($_g->get_refs);
            } else {
                vec($self->data->{subvec}, $_g, 1) = 1;
            }
        }
    }

    sub subsetByCId 
    {
        my $self = shift @_;
        my $g = shift @_;
        $self->data->{subset}=1;
        vec($self->data->{subvec},$g,1)=1;
        return if($self->iscff);
        if(defined $self->font->{loca}->read->{glyphs}->[$g]) {
            $self->font->{loca}->read->{glyphs}->[$g]->read;

            ## sometimes this reports errors
            eval {
              map { vec($self->data->{subvec},$_,1)=1; } $self->font->{loca}->{glyphs}->[$g]->get_refs;  
            };
            if ( $@ ) {
                $self->_map($self->font->{loca}->{glyphs}->[$g]->get_refs);
            }
        }
    }
}

PDF::API2::addFontDirs(qq{$ENV{SDRROOT}/imgsrv/share/fonts});

1;