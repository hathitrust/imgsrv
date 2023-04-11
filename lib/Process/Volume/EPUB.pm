package Process::Volume::EPUB;

use strict;
use warnings;

use Plack::Util;
use Plack::Util::Accessor qw( 
    access_stmts 
    display_name 
    institution 
    proxy 
    handle 
    format 
    file
    pages 
    searchable 
    output_filename 
    progress_filepath
    cache_dir
    download_url
    restricted 
    target_ppi 
    watermark
    watermark_filename 
    include_images
    output_fh
    working_dir
    updater
    layout
    packager
);

use Builder;

use Process::Text;
use Process::Image;
use Image::ExifTool;

use SRV::Utils;
use SRV::Globals;

use File::Basename qw(basename dirname fileparse);
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Slurp;
use Data::Dumper;
use List::MoreUtils qw(any);
use POSIX qw(strftime);
use Time::HiRes;

use List::Util qw(max);
use Data::Dumper;
use IO::File;

use File::Temp qw(tempdir);

use POSIX qw(strftime);

use ISO639;

use IPC::Run;
use File::pushd;

our $MIN_FILE_SIZE = 50;

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

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $auth = $C->get_object('Auth');

    # will need to so something different for status
    my $working_dir = tempdir(DIR => $self->cache_dir, CLEANUP => 1);
    # my $working_dir = qq{$ENV{SDRROOT}/sandbox/web/epub-dev/epub3-test/$$};
    make_path($working_dir);
    $self->working_dir($working_dir);

    my $packager_class_name = "Package::EPUB::" . ( $mdpItem->Get('item_subclass') || "Volume" );
    my $packager_class = Plack::Util::load_class($packager_class_name);
    $self->packager($packager_class->new(
        mdpItem => $mdpItem,
        auth => $auth,
        updater => $self->updater,
        display_name => $self->display_name,
        institution => $self->institution,
        access_stmts => $self->access_stmts,
        restricted => $self->restricted,
        handle => $self->handle,
        working_dir => $working_dir,
        pages => $self->pages,
        include_images => ($self->include_images || 0),
        watermark => $self->watermark,
    ));

    eval {
        $self->packager->generate($env);
    };
    if ( my $err = $@ ) {
        die "COULD NOT GENERATE EPUB: $err";
    }

    $self->open_container();

    $self->insert_colophon_page($env);

    $self->pack_zip();

    my $do_rename = 1;

    # and then rename the output_file
    if ( $do_rename ) {
        rename($self->output_filename . ".download", $self->output_filename) || die $!;
    }

    return {
        filename => $self->output_filename,
        mimetype => "application/epub+zip"
    };
}


sub creation_date {
    my $self = shift;
    my @now = gmtime;
    return sprintf "D:%4u%0.2u%0.2u%0.2u%0.2u%0.2u",
        $now[5] + 1900, $now[4] + 1,
        $now[3], $now[2],
        $now[1], $now[0];
}

sub add_watermarks {
    my $self = shift;
    my ( $mdpItem, $install_path ) = @_;

    my $retval = [];
    my ( $watermark_digitized, $watermark_original );
    if ( $self->watermark ) {
        ( $watermark_digitized, $watermark_original ) = SRV::Utils::get_watermark_filename($mdpItem, { size => 100 });
    }

    if ( $watermark_digitized ) {
        copy("$watermark_digitized.png", "$install_path/watermark_digitized.png");
        # $self->copy_file(source => "$watermark_digitized.png", filename => "images/watermark_digitized.png", id => "watermark-digitized", mimetype => "image/png");
    } else {
        copy("$Process::Globals::static_path/graphics/1x1.png", "$install_path/watermark_digitized.png");
        # $self->copy_file(source => "$Process::Globals::static_path/graphics/1x1.png", filename => "images/watermark_digitized.png", id => "watermark-digitized", mimetype => "image/png");
    }
    push @$retval, { filename => "hathitrust/watermark_digitized.png", id => "watermark-digitized", mimetype => "image/png" };

    if ( $watermark_original ) {
        copy("$watermark_original.png", "$install_path/watermark_original.png");
    } else {
        copy("$Process::Globals::static_path/graphics/1x1.png", "$install_path/watermark_original.png");
    }
    push @$retval, { filename => "hathitrust/watermark_original.png", id => "watermark-original", mimetype => "image/png" };
    # $self->copy_file(source => "$watermark_original.png", filename => "images/watermark_original.png", id => "watermark-original", mimetype => "image/png");

    return $retval;
}

sub open_container {
    my $self = shift;
    my $working_dir = $self->working_dir;
    my $container = XML::LibXML->load_xml(location => "$working_dir/META-INF/container.xml");
    my $container_xpc = XML::LibXML::XPathContext->new($container);
    $container_xpc->registerNs("x", "urn:oasis:names:tc:opendocument:xmlns:container");
    $$self{package_filename} = $container_xpc->findvalue('//x:rootfile[1]/@full-path');
    $$self{package_path} = dirname($$self{package_filename});
}

sub insert_colophon_page {
    my $self = shift;
    my ( $env ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $auth = $C->get_object('Auth');

    my $builder = Builder->new;
    my $xml = $builder->block('Builder::XML', { indent => 4, newline => 1 });

    my $working_dir = $self->working_dir;

    my $package_path = $$self{package_path};

    make_path(qq{$working_dir/$package_path/hathitrust});
    my $watermarks = $self->add_watermarks($mdpItem, "$working_dir/$package_path/hathitrust");
    copy(qq{$Process::Globals::static_path/graphics/hathi-logo-tm-600.png}, "$working_dir/$package_path/hathitrust/hathi-logo-tm.png");
    copy(qq{$Process::Globals::static_path/epub/colophon.css}, "$working_dir/$package_path/hathitrust/colophon.css");

    my $display_name = $self->display_name;
    my $institution = $self->institution;
    my $access_stmts = $self->access_stmts;
    my $proxy = $self->proxy;

    my $publisher = $mdpItem->GetPublisher();
    my $title = $mdpItem->GetFullTitle();
    my $author = $mdpItem->GetAuthor();

    my $handle = SRV::Utils::get_itemhandle($mdpItem);

    my $viewport = $self->packager->viewport;
    $xml->html({ 'xmlns' => 'http://www.w3.org/1999/xhtml' }, sub {
        $xml->head(sub {
            $xml->title("About this Download...");
            $xml->link({rel => 'stylesheet', type => 'text/css', href => '../hathitrust/colophon.css'});
            # maybe there's a viewport
            if ( ref $viewport ) {
                $xml->meta({ name => 'viewport', content => "width=$$viewport{width},height=$$viewport{height}" });
            }
        });
        my $args = {};
        $$args{class} = ref($viewport) eq 'pre-paginated' ? 'pre-paginated' : 'paginated';
        if ( $$args{class} eq 'pre-paginated' ) {
            $$args{style} = "width: $$viewport{width}px; height: $$viewport{height}px";
        }
        $xml->body($args,
            $xml->div({class => 'about-book'},
                $xml->h1($title),
                $xml->p({ class => 'metadata'},
                    $xml->span($author),
                    $xml->br,
                    $xml->span($publisher),
                ),
                $xml->p({ class => 'image' },
                    $xml->img({ src => '../hathitrust/hathi-logo-tm.png'}),
                ),
                $xml->p({ class => 'watermark' },
                    $xml->img({ class => 'watermark-digitized', src => '../hathitrust/watermark_digitized.png'}),
                    $xml->img({ class => 'watermark-original', src => '../hathitrust/watermark_original.png'}),
                ),
                $xml->p(
                    $xml->span("Copyright "),
                    $xml->a({ href => $$access_stmts{stmt_url} }, $$access_stmts{stmt_head})
                ),
                $xml->blockquote(
                    $xml->p($$access_stmts{stmt_text})
                ),
                $xml->p(
                    $xml->span("Find this Book Online: "),
                    $xml->a({ href => $handle }, $handle),
                ),
                $self->packager->additional_message($xml)
            )
        );
    });
    my $contents = $builder->render;

    write_file("$working_dir/$package_path/hathitrust/hathitrust-colophon.xhtml", {binmode => ':utf8'}, $contents);

    # now we amend the existing contents.opf and nav? no.
    my $package = XML::LibXML->load_xml(location => qq{$working_dir/$$self{package_filename}});
    my $xpc = XML::LibXML::XPathContext->new($package);
    my $ns = "http://www.idpf.org/2007/opf";
    $xpc->registerNs("opf", $ns);
    my $manifest = $xpc->findnodes(qq{//opf:manifest})->[0];
    my $item;
    $item = $package->createElementNS($ns, "item");
    $item->setAttribute('id', 'hathitrust_colophon');
    $item->setAttribute('href', 'hathitrust/hathitrust-colophon.xhtml');
    $item->setAttribute('media-type', 'application/xhtml+xml');
    $manifest->appendChild($item);

    $item = $package->createElementNS($ns, "item");
    $item->setAttribute('id', 'hathitrust_logo');
    $item->setAttribute('href', 'hathitrust/hathi-logo-tm.png');
    $item->setAttribute('media-type', 'image/png');
    $manifest->appendChild($item);

    $item = $package->createElementNS($ns, "item");
    $item->setAttribute('id', 'colophon-stylesheet');
    $item->setAttribute('href', 'hathitrust/colophon.css');
    $item->setAttribute('media-type', 'text/css');
    $manifest->appendChild($item);

    foreach my $mark ( @$watermarks ) {
        $item = $package->createElementNS($ns, "item");
        $item->setAttribute('id', $$mark{id});
        $item->setAttribute('href', $$mark{filename});
        $item->setAttribute('media-type', $$mark{mimetype});
        $manifest->appendChild($item);
    }

    my $spine = $xpc->findnodes(qq{//opf:spine})->[0];
    my $itemref = $package->createElementNS($ns, "itemref");
    $itemref->setAttribute('idref', 'hathitrust_colophon');
    my $first = $spine->firstChild;
    $spine->insertBefore($itemref, $first);

    write_file(qq{$working_dir/$$self{package_filename}}, {binmode => ':utf8'}, $package->toString);

    # my $nav_item = $xpc->find(q{//opf:item[@properties="nav"]});
    # if ( $nav_item ) {
    #     my $href = $nav_item->[0]->getAttribute('href');
    #     my $contents = XML::LibXML->load_xml(location => "$working_dir/$package_path/$href");
    #     my @tmp = split(/\//, $href);
    #     pop @tmp; # the navigation file

    #     my $xpc_xhtml = XML::LibXML::XPathContext->new($contents);
    #     $xpc_xhtml->registerNs("xhtml", 'http://www.w3.org/1999/xhtml');
    #     my $ol = $xpc_xhtml->findnodes("//xhtml:ol")->[0];
    #     my $li = $contents->createElementNS('http://www.w3.org/1999/xhtml', "li");
    #     my $a = $contents->createElementNS('http://www.w3.org/1999/xhtml', "a");
    #     $li->appendChild($a);
    #     $a->setAttribute('href', ( '../' x scalar @tmp ) . 'hathitrust/hathitrust-colophon.xhtml');
    #     $a->appendText("About this download");
    #     my $first = $ol->firstChild;
    #     $ol->insertBefore($li, $first);

    #     write_file(qq{$working_dir/$package_path/$href}, {binmode => ':utf8'}, $contents->toString);
    # }
}

sub pack_zip {
    my $self = shift;
    my $working_dir = $self->working_dir;
    my $epub_filename = $self->output_filename . ".download";
    my $ZIP_PROG = "/usr/bin/zip";

    {
        my $dir = pushd($working_dir);

        IPC::Run::run([ $ZIP_PROG, "-X", $epub_filename, 'mimetype' ]);
        IPC::Run::run([ $ZIP_PROG, "-rg", $epub_filename, 'META-INF', '-x', '*.DS_Store' ]);

        my $package_path = $$self{package_path};
        IPC::Run::run([ $ZIP_PROG, "-rg", $epub_filename, $package_path, '-x', '*.DS_Store' ]);
    }

    return $epub_filename;
}

1;