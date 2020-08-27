package Process::Volume::Utils;

use Process::Text;

sub get_text_lines {
    my ( $filename ) = @_;
    # default is to just do plain text
    my $fh = IO::File->new();
    $fh->open($filename);
    local $/ = undef;
    my $buffer = <$fh>;
    $fh->close;

    $buffer =~ s!\015\012!\012!gsm; $buffer =~ s!\015!\012!gsm;
    # utf8::decode($buffer);

    # make sure to avoid any blank lines
    my @lines = split(/\n/, $buffer);
    return { uses_coordinates => 0, lines => \@lines };
}

sub get_text_coordinates {
    my ( $filename ) = @_;
    my $p = Process::Text->new({serialize => 0});
    $p->source(filename => $filename);
    $p->_process_source();

    use Carp;

    my $output = eval {
        local $SIG{__DIE__} = \&Carp::confess;
        if ( $p->format eq 'application/alto+xml' ) {
            return get_text_coordinates_alto($p);
        } elsif ( $p->format eq 'application/djvu+xml') {
            return get_text_coordinates_djvu($p);
        } elsif ( $p->format eq 'text/abby+html' || $p->format eq 'text/html' ) {
            return get_text_coordinates_hocr($p);
        } else {
            return get_text_lines($filename);
        }
    };

    if ( my $err = $@ ) {
        # unknown format, or an issue parsing the coordinate OCR returns simple data
        die $err;
    }

    return $output;

}

sub get_text_coordinates_alto {
    my ( $process ) = @_;
    my $xmlDoc = $process->dom->documentElement;

    my $ns = "";
    my $xpc = XML::LibXML::XPathContext->new($xmlDoc);
    if ( my $xmlns_uri = $xmlDoc->getAttribute('xmlns') ) {
        $ns = "alto:";
        $xpc->registerNs("alto", $xmlns_uri);
    }

    my $XPATH_TEXTSTYLE = qq{/${ns}alto/${ns}Styles/${ns}TextStyle};
    my $XPATH_PAGE_WIDTH = qq{/${ns}alto/${ns}Layout/${ns}Page/\@WIDTH};
    my $XPATH_PAGE_HEIGHT = qq{/${ns}alto/${ns}Layout/${ns}Page/\@HEIGHT};
    my $XPATH_PAGE_BOTTOMMARGIN_HEIGHT = qq{/${ns}alto/${ns}Layout/${ns}Page/${ns}BottomMargin/\@HEIGHT};
    my $XPATH_PAGE_TOPMARGIN_HEIGHT = qq{/${ns}alto/${ns}Layout/${ns}Page/${ns}TopMargin/\@HEIGHT};
    my $XPATH_PAGE_RIGHTMARGIN_WIDTH = qq{/${ns}alto/${ns}Layout/${ns}Page/${ns}RightMargin/\@WIDTH};
    my $XPATH_PAGE_LEFTARGIN_WIDTH = qq{/${ns}alto/${ns}Layout/${ns}Page/${ns}LeftMargin/\@WIDTH};
    my $XPATH_TEXTBLOCK = qq{/${ns}alto//${ns}TextBlock};
    # my $XPATH_TEXTBLOCK = qq{/${ns}alto/${ns}Layout/${ns}Page/${ns}PrintSpace/${ns}TextBlock};

    my $output = { uses_coordinates => 1 };
    my %styles = ();
    foreach my $textStyle ( $xpc->findnodes($XPATH_TEXTSTYLE) ) {
        $styles{$textStyle->getAttribute('ID')} = { FONTSIZE => $textStyle->getAttribute('FONTSIZE'), FONTFAMILY => $textStyle->getAttribute('FONTFAMILY') };
    }

    $$output{width} = $xpc->findvalue($XPATH_PAGE_WIDTH);
    $$output{height} = $xpc->findvalue($XPATH_PAGE_HEIGHT);

    ## print STDERR "OUTPUT $$output{width} x $$output{height}\n";

    ## can you calculate width x height from margins?
    ## not completely, and SO FAR anecdotally when this happens it's best to 
    ## just assume width x height matches the image dimensions.
    if ( 0 && $$output{height} == 0 && $$output{width} == 0 ) {
        # stupid
        my $bottom_margin = $xpc->findvalue($XPATH_PAGE_BOTTOMMARGIN_HEIGHT);
        if ( $bottom_margin < 0 ) {
            $$output{height} = abs($bottom_margin) + $xpc->findvalue($XPATH_PAGE_TOPMARGIN_HEIGHT);
        }
        my $right_margin = $xpc->findvalue($XPATH_PAGE_RIGHTMARGIN_WIDTH);
        if ( $right_margin < 0 ) {
            $$output{width} = abs($right_margin) + $xpc->findvalue($XPATH_PAGE_LEFTARGIN_WIDTH);
        }
    }

    ## print STDERR "OUTPUT DEUX $$output{width} x $$output{height}\n";

    $$output{words} = [];
    $$output{xmlDoc} = $xmlDoc;

    foreach my $textBlock ( $xpc->findnodes($XPATH_TEXTBLOCK) ) {
        # print STDERR "AHOY : " . $textBlock->getAttribute('ID') . "\n";
        my @textBlockStyle = split(/ /, $textBlock->getAttribute('STYLEREFS'));
        my $font_family; my $font_size;
        foreach my $style ( @textBlockStyle ) {
            next unless ( ref $styles{$style} );
            $font_family = $styles{$style}{FONTFAMILY};
            $font_size = $styles{$style}{FONTSIZE};
        }

        foreach my $string ( $xpc->findnodes(".//${ns}String", $textBlock) ) {
            my $x0 = $string->getAttribute('HPOS');
            my $y0 = $string->getAttribute('VPOS');
            my $w0 = $string->getAttribute('WIDTH');
            my $h0 = $string->getAttribute('HEIGHT');
            my $content = $string->getAttribute('CONTENT');
            $content =~ s,^\s*,,; $content =~ s,\s*$,,g;

            if ( $h0 <= 0 || ! $content ) { next ; }

            # print STDERR "FETCH : $x0 : $y0 : $content\n";

            push @{ $$output{words} }, {
                top => $y0,
                left => $x0,
                width => $w0,
                height => $h0,
                font_family => $font_family,
                font_size => $font_size,
                content => $content,
            };

        }
    }

    return $output;

}

sub get_text_coordinates_hocr {
    my ( $process ) = @_;
    my $xmlDoc = $process->dom->documentElement;

    my $style2hash = sub {
        my $style = shift;
        my $hash = undef;
        if ( $style ) {
            $hash = {};
            foreach my $kv ( split(/;/, $style) ) {
                my ( $k, $v ) = split(/:/, $kv );
                $$hash{$k} = $v;
            }
        }
        return $hash;
    };

    my $title2hash = sub {
        my $title = shift;
        my $hash = undef;
        if ( $title ) {
            $hash = {};
            foreach my $kv ( split(/;/, $title) ) {
                my ( $k, $v ) = split(/ /, $kv, 2);
                $$hash{$k} = $v;
            }
        }
        return $hash;
    };

    my $output = { uses_coordinates => 1 };
    my $div = ($xmlDoc->findnodes(q{//div[@class="ocr_page"]}))[0];
    my $properties = $title2hash->($div->getAttribute('title'));
    my $page_box = $$properties{bbox};
    my ( $px0, $py0, $px1, $py1 ) = split(/ /, $page_box);

    $$output{width} = ( $px1 - $px0 );
    $$output{height} = ( $py1 - $py0 );

    $$output{words} = [];
    $$output{xmlDoc} = $xmlDoc;

    foreach my $p ( $xmlDoc->findnodes(q{//p[@class="ocr_par"]}) ) {
        my $p_style = $style2hash->($p->getAttribute('style'));
        foreach my $span ( $p->findnodes(q{.//span[@class="ocrx_word"]})) { # 
            my $bbox = $span->getAttribute('title');
            $bbox =~ s!^bbox !!gsm;
            my ( $x0, $y0, $x1, $y1 ) = split(/ /, $bbox);
            my $w0 = ( $x1 - $x0 );
            my $h0 = abs($y1 - $y0);
            
            my $span_style = $style2hash->($span->getAttribute('style'));
            
            my $text = $span->textContent();
            $text =~ s!^\s+!!gsm; $text =~ s!\s+$!!gsm;
            
            my $style = $span_style ? $span_style : $p_style;

            # print STDERR Data::Dumper::Dumper($style).  "\n";
            # my $font_size = $$style{'font-size'};
            # $font_size =~ m,pt,,;

            push @{ $$output{words} }, {
                top => $y0,
                left => $x0,
                width => $w0,
                height => $h0,
                font_family => $$style{'font-family'},
                font_size => $$style{'font-size'},
                content => $text,
            };

        }
    }

    return $output;    
}

sub get_text_coordinates_djvu {
    my ( $process ) = @_;
    my $xmlDoc = $process->dom->documentElement;

    my $output = { uses_coordinates => 1 };

    $$output{width}  = $xmlDoc->findvalue("/DjVuXML/BODY/OBJECT/\@width");
    $$output{height} = $xmlDoc->findvalue("/DjVuXML/BODY/OBJECT/\@height");

    $$output{words} = [];
    $$output{xmlDoc} = $xmlDoc;

    foreach my $string ( $xmlDoc->findnodes("//WORD") ) {
        my $word_font; my $word_font_size;
        $word_font = $font;

        my ( $x0, $y1, $x1, $y0 ) = split(/,/, $string->getAttribute('coords'));
        my $text = $string->findvalue('string(.)');

        my $w0 = ( $x1 - $x0 );
        my $h0 = abs($y0 - $y1);

        push @{ $$output{words} }, {
            top => $y0,
            left => $x0,
            width => $w0,
            height => $h0,
            font_family => q{Helvetica},
            font_size => 9,
            content => $text,
        };

    }

    return $output;
}

1;