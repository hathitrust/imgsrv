package Package::EPUB::Volume;

use strict;
use warnings;

use parent qw( Plack::Component );

use Plack::Util;
use Plack::Util::Accessor qw(
    access_stmts 
    display_name 
    institution 
    proxy 
    handle 
    output_filename 
    progress_filepath 
    cache_dir
    download_url
    marker
    restricted 
    watermark 
    id
    updater
    working_dir
    layout
    mdpItem
    auth
    pages
    include_images
);

use Builder;

use Process::Globals;
use Process::Text;
use Process::Image;
use Image::ExifTool;

use SRV::Utils;
use SRV::Globals;

use Data::Dumper;
use IO::File;

use File::Temp qw(tempdir);

use POSIX qw(strftime);

use ISO639;

use File::Basename qw(basename dirname fileparse);
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Slurp qw();
use Data::Dumper;
use List::MoreUtils qw(any);
use POSIX qw(strftime);
use Time::HiRes;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    $$self{package_items} = [];
    $$self{viewport} = { height => 0, width => 0 };
    $self->include_images(0) unless ( defined $self->include_images );

    $self;
}

sub generate {
    my $self = shift;
    my ( $env ) = @_;

    $self->layout('pre-paginated') if ( $self->include_images );

    my $mdpItem = $self->mdpItem;
    my $auth = $self->auth;

    $$self{builder} = Builder->new;
    $$self{xml} = $$self{builder}->block('Builder::XML', { indent => 4, newline => 1 });
    $$self{xml_dc} = $$self{builder}->block('Builder::XML', { namespace => 'dc', indent => 4, newline => 1 });

    $self->make_structure;
    $self->generate_mimetype;

    $self->copy_file(source => "$Process::Globals::static_path/epub/stylesheet.css", 
        filename => "styles/stylesheet.css", 
        id => "stylesheet", 
        mimetype => "text/css");

    my $updater = $self->updater;

    $$self{readingOrder} = $mdpItem->Get('readingOrder');

    my $nav = $self->build_navigation();

    die "EPUB CANCELLED" if ( $updater->is_cancelled );

    $updater->update(0);

    $self->build_content();

    $self->build_toc($nav);

    die "EPUB CANCELLED" if ( $updater->is_cancelled );

    $self->build_package();

    $self->build_container();

    $updater->finish();

    return 1;

}

sub build_navigation {
    my $self = shift;

    my $nav = [];
    my $mdpItem = $self->mdpItem;
    my $updater = $self->updater;

    my $current_feature = '';
    my $chapter_idx = 0; my $nav_idx = 0; my $file_idx = 0;
    my %NAV_FEATURES = (
        CHAPTER_START => q{Chapter __NUM__},
        INDEX => q{Index},
        TABLE_OF_CONTENTS => q{Contents},
        FRONT_COVER => q{Front Cover},
        BACK_COVER => q{Back Cover},
        COPYRIGHT => q{Copyright},
        TITLE => q{Title Page}
    );

    # first, see if we can concatenate the pages by chapter
    my $pageInfoHashRef = $mdpItem->Get( 'pageinfo' );
    my $current_size = 0;

    my $i = 0; my $section_idx = 0;
    foreach my $seq ( @{ $self->pages } ) {

        die "EPUB CANCELLED" if ( $updater->is_cancelled );

        $i += 1;
        # print STDERR "EPUB UPDATING $i\n";
        ## $updater->update($i);

        my %page_features = map { $_ => 1 } $mdpItem->GetPageFeatures($seq);
        my $feature;
        foreach my $f ( keys %page_features ) {
            if ( $NAV_FEATURES{$f} ) {
                # this is a break!
                $feature = $f;
                last;
            }
        }

        # my $ocr_file_size = $mdpItem->GetFileSizeBySequence($seq, 'ocrfile');
        my $info;

        if ( $feature && ( $feature ne $current_feature || $feature eq 'CHAPTER_START' ) ) {
            # this is a break
            $current_feature = $feature;
            my $num;
            if ( $mdpItem->HasPageNumbers() ) {
                $num = $$pageInfoHashRef{ 'sequence' }{ $seq }{ 'pagenumber' };
            }
            $info = { label => $NAV_FEATURES{$feature}, num => $num, seq => $seq };
        }

        if ( ref($info) ) {
            push @$nav, $info;
            $current_size = 0;   
            $section_idx += 1;
        }
    }

    return $nav;
}

sub build_content {
    my $self = shift;

    my $updater = $self->updater;
    my $mdpItem = $self->mdpItem;

    my $i = 0;
    my $has_content = 0;
    foreach my $seq ( @{ $self->pages } ) {

        die "EPUB CANCELLED" if ( $updater->is_cancelled );
        print STDERR "EPUB TRANSFORMING $i\n";

        $i += 1;
        $updater->update($i);

        $has_content += 1;

        my $xslt_params = $self->process_page_image($seq);
        $self->process_page_text($seq, $xslt_params);
    }
}

sub build_toc {
    my $self = shift;
    my ( $nav ) = @_;

    my $mdpItem = $self->mdpItem;

    if ( scalar @$nav ) {

        $$self{xml}->html({ xmlns => 'http://www.w3.org/1999/xhtml' },
            $$self{xml}->head(
                $$self{xml}->meta({ name => 'viewport', content => "width=800,height=1600" }),
                $$self{xml}->title("Contents")
            ),
            $$self{xml}->body(
                $$self{xml}->nav({ id => "toc", 'xmlns:epub' => 'http://www.idpf.org/2007/ops', 'epub:type' => 'toc' }, sub {
                    $$self{xml}->h1('Table of Contents');
                    $$self{xml}->ol(sub {
                        my $chapter_idx = 0;
                        foreach my $item ( @$nav ) {
                            my $seq = $$item{seq};
                            my $ocr_filename = $mdpItem->GetFileNameBySequence($seq, 'ocrfile');
                            my $basename = basename($ocr_filename, ".txt");
                            my $label = $$item{label};
                            if ( $label =~ m,^Chapter, ) {
                                $chapter_idx += 1;
                                $label =~ s,__NUM__,$chapter_idx,;
                            }
                            $$self{xml}->li(
                                $$self{xml}->a({ href => "xhtml/$basename.xhtml" }, $label)
                            );
                        }
                    });
                })
            )
        );

        $self->write_file($$self{builder}->render(), id => "toc", filename => "toc.xhtml", mimetype => "application/xhtml+xml", splice => 0, properties => "nav");
    }
}

sub build_package {
    my $self = shift;

    my $mdpItem = $self->mdpItem;
    my $package_items = $$self{package_items};

    $$self{xml}->package({ 'xmlns' => 'http://www.idpf.org/2007/opf', 'unique-identifier' => 'HathiTrustID', 'version' => '3.0' }, sub {
        $$self{xml}->metadata({'xmlns:rendition' => 'http://www.idpf.org/2013/rendition', 
                        'xmlns:dc' => 'http://purl.org/dc/elements/1.1/', 
                        'xmlns:dcterms' => 'http://purl.org/dc/terms'}, sub {

            $$self{xml_dc}->identifier({ id => 'HathiTrustID' }, $mdpItem->GetId());

            my $language = $mdpItem->GetLanguageCode() || 'und';
            if ( $language =~ m,</str>, ) {
                $language =~ s,</str>.*,,;
            }
            $$self{xml_dc}->language(ISO639::rfc5646($language));
            $$self{xml_dc}->title($mdpItem->GetFullTitle()),
            $$self{xml_dc}->source("https://hdl.handle.net/2027/" . $mdpItem->GetId()),

            my $modified = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($mdpItem->get_modtime));
            $$self{xml}->meta({property => "dcterms:modified"}, $modified);

            if ( my $publication_date = $mdpItem->GetPublicationDate() ) {
                # this may not be technically valid https://www.loc.gov/marc/bibliographic/bd260.html
                $$self{xml_dc}->date($publication_date);
            }

            if ( $self->include_images ) {
                # print STDERR "AHOY WAT pre-paginated\n";
                $$self{xml}->meta({property => "rendition:layout"}, "pre-paginated");
            }
            $$self{xml}->meta({property => "rendition:orientation"}, "auto");
            $$self{xml}->meta({property => "rendition:spread"}, "auto");

        }),
        $$self{xml}->manifest(sub {
            foreach my $item ( @$package_items ) {
                my $args = { id => $$item{id}, href => $$item{filename}, 'media-type' => $$item{mimetype} };
                $$args{properties} = $$item{properties} if ( $$item{properties} );
                $$self{xml}->item($args);
            }
        }),
        $$self{xml}->spine(sub {
            foreach my $item ( @$package_items ) {
                next unless ( $$item{mimetype} eq 'application/xhtml+xml' );
                next if ( $$item{id} eq 'toc' );
                $$self{xml}->itemref({ idref => $$item{id} });
            }
        })
    });

    $self->write_file($$self{builder}->render(), filename => "content.opf");
}

sub build_container {
    my $self = shift;


    # build the rootfile
    $$self{xml}->container({ xmlns => 'urn:oasis:names:tc:opendocument:xmlns:container', 'xmlns:rendition' => 'http://www.idpf.org/2013/rendition', version => '1.0' },
        $$self{xml}->rootfiles(
            $$self{xml}->rootfile({
                'full-path' => 'OEBPS/content.opf',
                'media-type' => 'application/oebps-package+xml',
                'rendition:label' => 'Text',
                'rendition:layout' => $self->rendition_layout,
                'rendition:media' => '(orientation:portrait)',
                'rendition:accessMode' => 'visual'
            })
        )
    );
    $self->write_file($$self{builder}->render(), filename => "/META-INF/container.xml");
}

sub rendition_layout {
    my $self = shift;
    return $self->include_images ? 'pre-paginated' : 'reflowable';
}

sub pathname {
    my $self = shift;
    my ( $pathname ) = @_;

    $pathname = "OEBPS/$pathname" unless ( $pathname =~ m,^/, );

    return join('/', $self->working_dir, $pathname);
}

sub copy_file {
    my $self = shift;
    my %args = @_;
    copy($args{source}, $self->pathname($args{filename})) || die $!;
    $self->add_file(%args) if ( $args{mimetype} );
}

sub write_file {
    my $self = shift;
    my ( $buffer, %args ) = @_;

    File::Slurp::write_file($self->pathname($args{filename}), {binmode => ':utf8'}, $buffer);
    $self->add_file(%args) if ( $args{mimetype} );
}

sub add_file {
    my $self = shift;
    my %args = @_;
    #         # push @$package_items, [ "images/watermark_original.png", "image/png", "watermark-original" ];

    if ( defined $args{splice} ) {
        unshift @{ $$self{package_items} }, \%args;
    } else {
        push @{ $$self{package_items} }, \%args;
    }
}

sub make_structure {
    my $self = shift;

    make_path($self->pathname(q{/META-INF}));
    make_path($self->pathname(qq{/OEBPS}));
    make_path($self->pathname(qq{/OEBPS/images})) if ( $self->include_images );
    make_path($self->pathname(qq{/OEBPS/styles}));
    make_path($self->pathname(qq{/OEBPS/xhtml}));
}

sub generate_mimetype {
    my $self = shift;
    # write_file(join('/', $self->working_dir, 'mimetype'), {binmode => ':utf8'}, q{application/epub+zip});
    $self->write_file("application/epub+zip", filename => "/mimetype");
}

sub viewport {
    my $self = shift;
    return $$self{viewport};
}

sub additional_message {
    my $self = shift;
    my ( $xml ) = @_;
    $xml->p({ class => 'warning' }, 
        $self->include_images ?
        "This file has been created from scanned page images and computer-extracted text. Computer-extracted text may have errors, such as misspellings, unusual characters, odd spacing and line breaks." : 
        "This file has been created from the computer-extracted text of scanned page images. Computer-extracted text may have errors, such as misspellings, unusual characters, odd spacing and line breaks."
    ),
}

sub get_page_basename {
    my $self = shift;
    my ( $seq ) = @_;
    unless ( ref($$self{basenames}) ) { $$self{basenames} = {}; }
    unless ( $$self{basenames}{$seq} ) {
        my $ocr_filename = $self->mdpItem->GetFileNameBySequence($seq, 'ocrfile');
        $$self{basenames}{$seq} = basename($ocr_filename, ".txt");
    }
    return $$self{basenames}{$seq};
}

sub process_page_image {
    my $self = shift;
    my ( $seq ) = @_;
    my $params = {};
    return $params unless ( $self->include_images );

    my $basename = $self->get_page_basename($seq);
    my $image_filename = $self->mdpItem->GetFileNameBySequence($seq, 'imagefile');
    my $image_filename_path = $self->mdpItem->GetFilePathMaybeExtract($seq, 'imagefile');
    my $processor = new Process::Image;
    $processor->source( filename => $image_filename_path );
    $processor->output( filename => $self->pathname("images/$basename.jpg") );
    $processor->format("image/jpeg");
    $processor->size("100");
    $processor->process();
    ( $$params{width}, $$params{height} ) = imgsize($processor->output->{filename});
    $$params{image_src} = "'../images/$basename.jpg'";

    if ( $$params{width} > $$self{viewport}{width} || $$params{height} > $$self{viewport}{height} ) {
        ( $$self{viewport}{width}, $$self{viewport}{height} ) = ( $$params{width}, $$params{height} );
    }

    $self->add_file(filename => "images/$basename.jpg", id => "image$basename", mimetype => "image/jpeg");
    return $params;
}

sub process_page_text {
    my $self = shift;
    my ( $seq, $xslt_params) = @_;

    my $basename = $self->get_page_basename($seq);

    my $input_filename_path;
    my $html_filename = $self->mdpItem->GetFileNameBySequence($seq, 'coordOCRfile');

    my $p = new Process::Text;
    $p->serialize(0);

    if ( $html_filename ) {
        $input_filename_path = $self->mdpItem->GetFilePathMaybeExtract($seq, 'coordOCRfile');
    } else {
        $input_filename_path = $self->mdpItem->GetFilePathMaybeExtract($seq, 'ocrfile');
    }

    $p->source(filename => $input_filename_path);
    $p->output(filename => $self->pathname(qq{xhtml/$basename.xhtml}));
    $p->add_transform(qq{$Process::Globals::static_path/epub/html2xhtml4epub.xsl}, $xslt_params);

    $p->process();
    $p->finish();
    $self->add_file(filename => "xhtml/$basename.xhtml", id => "xhtml$basename", mimetype => "application/xhtml+xml");

}

# hack

sub imgsize {
    my ( $filename ) = @_;
    my $info = Image::ExifTool::ImageInfo($filename);
    return ( $$info{ImageWidth}, $$info{ImageHeight} );
}

1;