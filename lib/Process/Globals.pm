package Process::Globals;
use File::Basename qw(dirname);

### Process::Image

$kdu_expand = qq{/l/local/bin/kdu_expand};
$kdu_compress = qq{/l/local/bin/kdu_compress};

$grk_decompress = qq{/usr/bin/grk_decompress};
$grk_compress   = qq{/usr/bin/grk_compress};

$NETPBM_ROOT = qq{/l/local/bin};
$pamflip = qq{$NETPBM_ROOT/pamflip};
$jpegtopnm = qq{$NETPBM_ROOT/jpegtopnm};
$tifftopnm = qq{$NETPBM_ROOT/tifftopnm};
$bmptopnm = qq{$NETPBM_ROOT/bmptopnm};
$pngtopam = qq{$NETPBM_ROOT/pngtopam};
$ppmmake = qq{$NETPBM_ROOT/ppmmake};

$pamcomp = qq{$NETPBM_ROOT/pamcomp};
$pnmscalefixed = qq{$NETPBM_ROOT/pnmscalefixed};
$pamscale = qq{$NETPBM_ROOT/pamscale};
$pamflip = qq{$NETPBM_ROOT/pamflip};
$pnmrotate = qq{$NETPBM_ROOT/pnmrotate};
$pnmpad = qq{$NETPBM_ROOT/pnmpad};

$pamtotiff = qq{$NETPBM_ROOT/pamtotiff};
$pnmtotiff = qq{$NETPBM_ROOT/pnmtotiff};
$pnmtojpeg = qq{$NETPBM_ROOT/pnmtojpeg};
$pamrgbatopng = qq{$NETPBM_ROOT/pamrgbatopng};
$ppmtopgm = qq{$NETPBM_ROOT/ppmtopgm};
$pnmtopng = qq{$NETPBM_ROOT/pnmtopng};
$pamthreshold = qq{$NETPBM_ROOT/pamthreshold};

$convert = qq{/l/local/bin/convert};

$stdout = q{/tmp/stdout};
if ( $ENV{USER} ) { $stdout .= "_$ENV{USER}"; }
foreach my $ext ( qw/bmp ppm jpg png tif/ ) {
    if ( ! -l "$stdout.$ext" ) {
        symlink("/dev/stdout", "$stdout.$ext");
    }
}

$static_path = qq{$ENV{SDRROOT}/imgsrv/web}; # dirname(__FILE__) . q{/../../web};
$restricted_label = qq{$static_path/graphics/restricted_label};
$lock_icon = qq{$static_path/graphics/lock.png};

$default_width = 680;

### Default transformers
$transformers = {};
$$transformers{'image/jp2'} = 'grok';

### Process::Text

$transforms = ();
$$transforms{'application/djvu+xml'} = [qq{$static_path/text/djvu2xhtml.xsl}];
$$transforms{'application/alto+xml'} = [qq{$static_path/text/alto2xhtml.xsl}];
$$transforms{'text/abby+html'} = [qq{$static_path/text/abby2xhtml.xsl}];
$$transforms{'text/html'} = [qq{$static_path/text/abby2xhtml.xsl}];
$$transforms{'text/plain'} = [];

$$transforms{'application/jats+xml'} = 
    $$transforms{'http://dtd.nlm.nih.gov/publishing/3.0/journalpublishing3.dtd'} = 
        $$transforms{'http://dtd.nlm.nih.gov/publishing/3.0/journalpublishing3.dtd'} = 
        [ 
            qq{$ENV{SDRROOT}/mpach/JATSPreviewStylesheets/xslt/citations-prep/jats-PMCcit.xsl},
            qq{$ENV{SDRROOT}/mpach/JATSPreviewStylesheets/xslt/main/jats-mpub.xsl},
         ];

### Process::Article
$wkhtmltopdf = qq{$ENV{SDRROOT}/sandbox/bin/wkhtmltopdf};
$phantomjs = qq{$ENV{SDRROOT}/sandbox/bin/phantomjs};
$weasyprint = qq{};

$js_css_map = {};
$$js_css_map{'application/jats+xml'} = $$js_css_map{'http://dtd.nlm.nih.gov/publishing/3.0/journalpublishing3.dtd'} = {
    '__ROOT__' => '/mpach/',
    'jats-preview.css' => 'css/jpub-preview.css',
};

# $jquery_url = q{//ajax.googleapis.com/ajax/libs/jquery/1.8/jquery.min.js};
# $postmessage_url = q{/pt/vendor/jquery.ba-postmessage.js};
# $iframe_script_urls = [ q{/imgsrv/vendor/jquery.myhighlight-3.js}, q{/imgsrv/js/iframe_support.js}, q{/imgsrv/js/indexing.js} ];

### Process::*::PDF

@gNonWesternLanguages = (
    'Arabic',
    'Balinese',
    'Bengali',
    'Bopomofo',
    'Bopomofo',
    'Bugis',
    'Buhid',
    'Cherokee',
    'Chinese',
    'Coptic',
    'Cuneiform',
    'Deseret',
    'Devanagari',
    'Ethiopic',
    'Glagolitic',
    'Gothic',
    'Gujarati',
    'Gurmukhi',
    'Hangul',
    'Hangul Jamo',
    'Hanunoo',
    'Hebrew',
    'Hiragana',
    'Inuktitut',
    'Japanese',
    'Kanbun',
    'Kannada',
    'Katakana',
    'Katakana',
    'Kharoshthi',
    'Khmer',
    'Khmer',
    'Korean',
    'Limbu',
    'Linear B',
    'Malayalam',
    'Mongolian',
    'Myanmar',
    'Old Persian',
    'Oriya',
    'Osmanya',
    'Phags-pa',
    'Phoenician',
    'Runic',
    'Shavian',
    'Sichuan Yi',
    'Sinhala',
    'Syriac',
    'Tagalog',
    'Tagbanwa',
    'Tai',
    'Tamil',
    'Telugu',
    'Thaana',
    'Thai',
    'Tibetan',
    'Ugaritic',
);

1;