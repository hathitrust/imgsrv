package Process::Watermark::PDF;

use Plack::Util;
use Plack::Util::Accessor qw(
  handle
  display_name
  institution
  proxy
  access_stmts
  target_ppi
  mdpItem
  message
  watermark
  debug
  document
  output_filename
  marginalia_width
);

use Data::Dumper;
use IPC::Run qw();
use PDF::API2;
require PDF::API2::_patches;

use POSIX qw(strftime ceil);

use SRV::Utils;
use Process::Globals;

use constant LEFT_ALIGNED => 1;
use constant RIGHT_ALIGNED => 1;

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

sub run {
    my $self = shift;
    $self->start_initialization();
    $self->setup_generated_message();
    $self->setup_colophon_page();
    $self->setup_stamp_page();
    $self->finish_initialization();
}

sub cleanup {
    my $self = shift;
    unlink $self->output_filename if ( -f $self->output_filename );
}

sub start_initialization {
    my $self = shift;

    my $watermark_pdf = PDF::API2->new;
    $$watermark_pdf{forcecompress} = 0;
    $watermark_pdf->mediabox('Letter');

    $self->marginalia_width(0);

    $self->document($watermark_pdf);
}

sub finish_initialization {
    my $self = shift;

    $self->document->saveas($self->output_filename);
    $self->document(PDF::API2->open($self->output_filename));
}

sub setup_generated_message {
    my $self = shift;
    my ( $mdpItem, $watermark_pdf ) = ( $self->mdpItem, $self->document );

    my $display_name = $self->display_name;
    my $institution = $self->institution;
    my $proxy = $self->proxy;

    my @message = ('Generated');
    if ( $display_name ) {
        if ( $proxy ) {
            push @message, qq{by $display_name};
        }
        if ( $institution ) {
            push @message, qq{at $institution};
        }
        if ( $proxy ) {
            push @message, qq{for a print-disabled user};
        }
    }
    push @message, "on", strftime("%Y-%m-%d %H:%M GMT", gmtime());

    # if ( $self->target_ppi > 0 ) {
    #     push @message, " (${targetPPI}ppi)";
    # }

    push @message, " / ";
    push @message, $self->handle;

    my $message_1 = join(" ", @message);

    # attach the brief access statement?
    @message = ();
    push @message, $self->access_stmts->{stmt_head};
    push @message, " / ";
    push @message, $self->access_stmts->{stmt_url};
    my $message_2 = join(' ', @message);

    @message = ();
    my $message_3 = "";
    # attach proxy signature
    if ( $proxy ) {
        $message_3 = qq{\nSignature [ $proxy ]};
    }

    # monospace font for better URL legibility
    my $font = PDF::API2::_findFont('DejaVuSansMono.ttf');
    my $message_filename = SRV::Utils::generate_temporary_filename($mdpItem, 'message.png');

    IPC::Run::run [
      $Process::Globals::convert,
      "-fill", '#C0C0C0', # ( $self->debug ? '#B1B1B1' : 'rgba(177,177,177, 0.35)' ), #'#B1B1B1',
      "-background", "transparent",
      "-font", $font,
      "-density", "144",
      "-pointsize", "14",
      "label:$message_1\n$message_2$message_3",
      "-gravity", "west",
      "-depth", "8",
      "-rotate", "-90",
      $message_filename
    ];

    $self->message($watermark_pdf->image_png($message_filename))
}

sub insert_generated_message {
    my $self = shift;
    my ( $page, $image ) = @_;

    my $mdpItem = $self->mdpItem;

    my ( $x0, $y0, $x1, $y1 ) = $page->get_mediabox;

    # find a ratio based on a fraction of the page height (orig: 0.6)
    my $r = ( $y1 * 0.6 ) / $$self{message}->height;
    if ( $r < 0.25 ) {
        $r = ( $y1 * 0.9 ) / $$self{message}->height;
    }
    $r = 1 if ( $r > 1 );

    my $image_h = $$self{message}->height * $r;
    my $image_w = $$self{message}->width * $r;

    $self->marginalia_width($image_w);

    my $gfx = ref($image) ? $image : $page->gfx;
    $gfx->image($$self{message}, 2, 15, $image_w, $image_h);
}

sub setup_colophon_page {
    my $self = shift;
    my ( $mdpItem, $watermark_pdf ) = ( $self->mdpItem, $self->document );

    my $page = $watermark_pdf->page();
    $page->mediabox('Letter');
    my ( $x0, $y0, $x1, $y1 ) = $page->get_mediabox;

    $self->insert_generated_message($page);

    my $gfx; my $text;
    my $toprint;

    ## add book data
    my $title = $mdpItem->GetFullTitle(1);
    my $author = $mdpItem->GetAuthor(1);
    my $publisher = $mdpItem->GetPublisher(1);

    my $title_font_size = 12;
    my $font_size = 10;
    my $heading_width = int($x1 * 0.7); # pixels

    # set up cover page fonts

    my $plain_font = $watermark_pdf->ttfont('DejaVuSans.ttf', -encode => 'utf8', -unicodemap => 1);
    my $bold_font = $watermark_pdf->ttfont('DejaVuSans-Bold.ttf', -encode => 'utf8', -unicodemap => 1);
    my $mono_font = $watermark_pdf->ttfont('DejaVuSansMono.ttf', -encode => 'utf8', -unicodemap => 1);

    my $y_drift = 0;

    if ( $title ) {

        $gfx = $page->gfx;
        $gfx->save;
        $gfx->textstart;
        $gfx->translate(50, $y1 - 50);
        $gfx->fillcolor('#000000');
        $gfx->font($bold_font, $title_font_size);
        $gfx->lead($title_font_size * 1.25);

        while ( $title ) {
            ( $toprint, $title ) = $gfx->text_fill_left($title, $heading_width);
            $gfx->nl;
            $y_drift += $title_font_size * 1.25;
        }

        $gfx->font($plain_font, $font_size);
        $gfx->lead($font_size *1.25);

        $gfx->write_justified_text($author, $heading_width);
        $gfx->write_justified_text($publisher, $heading_width);

        $gfx->nl;
        $gfx->font($mono_font, $font_size);
        $gfx->write_justified_text($self->handle, $heading_width);

        $gfx->textend;
        $gfx->restore;

    }

    my $coverpage_image = qq{$SRV::Globals::gHtmlDir/common-web/graphics/HathiTrustDL_coverpage.jpg};

    my ( $image_w, $image_h ) = imgsize($coverpage_image);
    $image_h = $y1 / 3;
    $image_w = $x1 / 3;

    my ( $center_x, $center_y ) = ( $x1 / 2, $y1 / 2 );
    my $image_data = $watermark_pdf->image_jpeg($coverpage_image);
    my $image = $page->gfx;
    my $xpos = ( $center_x - ( $image_w / 2 ) );
    my $ypos = ( $center_y - ( $image_h / 2) );

    $ypos += ( 100 - $y_drift );

    $image->image($image_data, $xpos, $ypos, $image_w, $image_h);

    ## add the access statement

    $gfx = $page->gfx;
    $gfx->transform(-translate => [$xpos, $ypos - 15]);

    #### TO DO: if there's a stmt_icon, pull and embed
    #### in the PDF.
    # if ( $$self{access_stmts}{stmt_icon} ) {
    # }

    my $access_stmts = $self->access_stmts;

    $gfx->textstart;

    $gfx->font($bold_font, $font_size + 1);
    $gfx->lead(( $font_size + 1 ) * 1.25);
    $gfx->write_justified_text($$access_stmts{stmt_head}, $image_w);

    $gfx->font($mono_font, $font_size);
    $gfx->lead($font_size * 1.25);
    $gfx->fillcolor('#6C6C6C');
    $gfx->write_justified_text($$access_stmts{stmt_url}, $image_w);

    $gfx->nl;

    # # reduce the font size for very long text; will have to be revisited
    # # if the stmt_text runs long
    # if ( length($$self{access_stmts}{stmt_text}) > 960 ) {
    #     $font_size -= 1;
    # }

    $font_size = 8;
    $gfx->font($plain_font, $font_size);
    $gfx->lead($font_size * 1.25);
    $gfx->fillcolor('#6C6C6C');
    $gfx->write_justified_text($$access_stmts{stmt_text}, $image_w);

    $gfx->textend;

}

sub setup_stamp_page {
    my $self = shift;
    my ( $mdpItem, $watermark_pdf ) = ( $self->mdpItem, $self->document );

    my $page = $watermark_pdf->page();
    $page->mediabox('Letter');
    my ( $x0, $y0, $x1, $y1 ) = $page->get_mediabox;

    $self->insert_generated_message($page);

    if ( $self->watermark ) {

        my ($center_x, $center_y, $wm_margin_y);
        ($center_x, $center_y) = ($x1 / 4, $y1 / 4);
        $wm_margin_y = 30;

        ( $watermark_digitized, $watermark_original ) = SRV::Utils::get_watermark_filename($mdpItem, { size => 100 });
    
        eval {
            my $image = $page->gfx();

            if (defined($watermark_digitized)) {
                $watermark_digitized = $watermark_pdf->image_png("$watermark_digitized.png");
                $self->draw_image($image, $watermark_digitized, $center_x, $wm_margin_y);
            }

            if (defined($watermark_original)) {
                $watermark_original = $watermark_pdf->image_png("$watermark_original.png");
                $self->draw_image($image, $watermark_original, ( $center_x * 2 ) + $center_x, $wm_margin_y);
            }
        };
        if ( my $err = $@ ) {
            print STDERR "!! $err\n";
        }
    }
}

sub draw_image {
    my $self = shift;
    my ( $gfx, $image, $center_x, $y ) = @_;

    my ($wm_w, $wm_h) = ($image->width, $image->height);
    $wm_w *= 0.75;
    $wm_h *= 0.75;
    # center the watermark 30 pixels above the bottom.
    my ( $wm_x, $wm_y );
    $wm_x = $center_x - ($wm_w/2);
    $wm_y = $y;

    eval {
        $gfx->image($image, $wm_x, $wm_y, $wm_w, $wm_h);
    };
    if ( my $err = $@ ) {
        die "COULD NOT ADD WATERMARK\n$err";
    }

}

sub imgsize {
    my ( $filename ) = @_;
    my $info = Image::ExifTool::ImageInfo($filename);
    return ( $$info{ImageWidth}, $$info{ImageHeight} );
}

1;
