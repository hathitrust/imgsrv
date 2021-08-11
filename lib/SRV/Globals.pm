package SRV::Globals;

# unbuffered output
$| = 1;

# Apply the google watermark (may be affected by metadata indicating
# that the page image is DLPS created vs. Google created.
$gWatermarkingEnabled = 1;
$gUnrestrictedThumbnailsEnabled = 1;

$gMakeDirOutputLog    = '/tmp/imgsrvoutput.log';


$gDefaultSize         = '100';
$gDefaultSeq          = '1';
$gDefaultNum          = '1';

# map from user interface values to percentages (happens to look to be
# very one to one
%gSizes =
    (
     '400'  => 4.00,
     '375'  => 3.75,
     '350'  => 3.50,
     '325'  => 3.25,
     '300'  => 3.00,
     '275'  => 2.75, 
     '250'  => 2.50, 
     '225'  => 2.25, 
     '200'  => 2.00,
     '175'  => 1.75,
     '150'  => 1.50,
     '125'  => 1.25,
     '100'  => 1.00,
     '75'   => 0.75,
     '50'   => 0.50,
     '25'   => 0.25,
    );

%gWatermarkSizes =
    (
     '1000'  => 10.00,
     '800'  => 8.00,
     '600'  => 6.00,
     '500'  => 5.00,
     '400'  => 4.00,
     '300'  => 3.00,
     '200'  => 2.00,
     '175'  => 1.75,
     '150'  => 1.50,
     '125'  => 1.25,
     '100'  => 1.00,
     '75'   => 0.75,
     '50'   => 0.50,
     '25'   => 0.25,
    );

$gMaxThumbnailSize    = '250';
$gDefaultThumbnailSize = '150';

%gValidRotationValues =
    (
     '0' => '0',
     '1' => '90',
     '2' => '180',
     '3' => '270'
    );

## --------------------------------------------------

%gTargetMimeTypes = (
    'jpeg' => 'image/jpeg',
    'jpg' => 'image/jpeg',
    'png'  => 'image/png',
    'tif'  => 'image/png',
    'jp2'  => 'image/jpeg'
);

%gTargetFileTypes = (
    'image/jpeg' => 'jpg',
    'image/png'  => 'png',
    'image/tiff' => 'tif',
    'image/jp2'  => 'jp2',
);

# ---------------------------------------------------------------------
# location of html template files (web DocRoot space)
# ---------------------------------------------------------------------
$gHtmlDir          = $ENV{'SDRROOT'} . '/imgsrv/web/';     # actual doc root directory
$gHtmlDocRoot      = '/i/imgsrv/';   # server doc root alias

$gCacheDocRoot  = ($ENV{SDRVIEW} eq 'full') ? '/cache-full/imgsrv/' : '/cache/imgsrv/';

$gGraphicsHtmlDir  = $gHtmlDir . q{graphics/};
$gGraphicsHtmlRoot = $gHtmlDocRoot . q{graphics/};
$gWatermarksDir = $ENV{SDRROOT} . q{/watermarks/};

$watermark_config_filename = $gWatermarksDir . 'config.txt';

$gMissingPageImage = $gGraphicsHtmlDir . q{MissingPage.jpg};

$gWatermarkMinWidth = 320;

# watermarks have the following template: $gWatermarksHtmlDir . q{DigGoogle_OrigMichigan},
# 1 == DigGoogle_
# 2 == DigMichigan_
# 3 == DigMichiganPress_
# 4 == DigIA_
# 5 == DigYale_
# 6 == Dig(University of Minnesota)
# 7 == Dig(Minnesota Historical Society)
%gWatermarkImages = (
    'mdp' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigMichigan},
        '2' => $gWatermarksHtmlDir . q{DigMichigan_OrigMichigan},
        '3' => $gWatermarksHtmlDir . q{DigMichiganPress_OrigMichigan},
        '12' => $gWatermarksHtmlDir . q{DigMillenium_OrigMichigan},
        '13' => $gWatermarksHtmlDir . q{DigUIUC_OrigUIUC},
        '14' => $gWatermarksHtmlDir . q{DigBrooklynMuseum_OrigBrooklynMuseum},
        '19' => $gWatermarksHtmlDir . q{DigMichigan_OrigMichigan},
    },
    'miun' => {
        '2' => $gWatermarksHtmlDir . q{DigMichigan_OrigMichigan},
    },
    'miua' => {
        '2' => $gWatermarksHtmlDir . q{DigMichigan_OrigMichigan},
    },
    'wu'   => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigWisconsin},
    },
    'inu'  => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigIndiana},
    },
    'uc1'  => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigCalifornia},
    },
    'uc2'  => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigCalifornia},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigCalifornia},
    },
    'pst' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigPenn},
    },
    'umn' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigMinnesota},
    },
    'nyp' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigNYPL},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigNYPL},
    },
    'chi' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigChicago},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigChicago},
    },
    'nnc1' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigColumbia},
    },
    'nnc2' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigColumbia},
    },
    'yale' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigYale},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigYale},
        '5' => $gWatermarksHtmlDir . q{DigMicrosoft_OrigYale},
    },
    'njp' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigPrinceton},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigPrinceton},
    },
    #'uiuo' => {
    #    '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigIllinois},
    #    '4' => $gWatermarksHtmlDir . q{DigIA_OrigIllinois},
    #},
    'coo' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigCornell},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigCornell},
    },
    'ucm' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigMadrid},
        '9' => $gWatermarksHtmlDir . q{DigMadrid_OrigMadrid},
    },
    'mdl' => {
    },
    'ien' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigNorthwestern},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigNorthwestern},
    },
    'usu' => {
        '8' => $gWatermarksHtmlDir . q{DigUtahState_OrigUtahState},
    },
    'loc' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigLOC},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigLOC},
    },
    'hvd' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigHarvard},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigHarvard},
    },
    'uva' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigUVA},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigUVA},
    },
    'ncs1' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigNCSU},
    },
    'dul1' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigDuke},
    },
    'nc01' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigUNC},
    },
    'pur1' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigPurdue},
    },
    'pur2' => {
        '10' => $gWatermarksHtmlDir . q{DigPurdue_OrigPurdue},
    },
    'gri' => {
#        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigGetty},
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigGetty},
        '11' => $gWatermarksHtmlDir . q{DigGetty_OrigGetty},
    },
    'uiuc' => {
        '13' => $gWatermarksHtmlDir . q{DigUIUC_OrigUIUC},
    },
    'uiug' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigUIUC},
    },
    'uiuo' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigUIUC},
    },
    'psia' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigPennSt},
    },
    'bc' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigBostonColl},
        '23' => $gWatermarksHtmlDir . q{DigBostonColl_OrigBostonColl},
    },
    'ufl1' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigUF},
    },
    'ufl2' => {
        '15' => $gWatermarksHtmlDir . q{DigUF_OrigUF},
    },
    'keio' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigKeio},
    },
    'txa' => {
        '16' => $gWatermarksHtmlDir . q{DigTexasAM_OrigTexasAM},
    },
    'uma' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigUMassAm},
    },
    'osu' => {
        '1' => $gWatermarksHtmlDir . q{DigGoogle_OrigOhioState},
    },
    'caia' => {
        '4' => $gWatermarksHtmlDir . q{DigIA_OrigSterClarkArtInstitute},
        '20' => $gWatermarksHtmlDir . q{DigSterClarkArtInstitute_OrigSterClarkArtInstitute},
    },
    'ku01' => {
        '21' => $gWatermarksHtmlDir . q{OrigKnowledgeUnlatched},
    },
    'mcg' => {
        '22' => $gWatermarksHtmlDir . q{DigMcGill_OrigMcGill},
    },
);

%gMaxDimensions = (
    'mdl' => {
        '6' => 1024,
        '7' => 1024,
    },
);

# ----------------------------------------------------------------------
# Handle link stem
# ----------------------------------------------------------------------
$gHandleLinkStem = q{https://hdl.handle.net/2027/};

$gDefaultCoverPage = qq{$ENV{SDRROOT}/common/web/unicorn/img/nocover-thumbnail.png};

#------

$gMarkerPrefix = '2K16.11';

1;
