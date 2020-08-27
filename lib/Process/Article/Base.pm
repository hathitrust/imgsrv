package Process::Article::Base;

use Plack::Util::Accessor qw(
    output_filename
    progress_filename
    download_url
    working_path
    mdpItem
    display_name
    institution
    access_stmts
    proxy
    marker
    handle
    html_filenames
    updater
);

use SRV::Utils;
use Process::Globals;
use Process::Article::HTML;

use File::Basename qw(basename);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    $self->_initialize();

    $self;
}

sub _initialize {
    my $self = shift;
    unless ( $self->working_path ) {
        $self->working_path(SRV::Utils::generate_temporary_dirname($self->mdpItem, ref($self)));
    }
    $self->html_filenames([]);
};

sub gather_files {
    my $self = shift;
    my $env = shift;
    my $packager = shift;

    my $mdpItem = $self->mdpItem;

    my $content_type = $mdpItem->GetMarkupLanguage();
    my $map = $$Process::Globals::js_css_map{$content_type};

    foreach my $key ( keys %$map ) {
        next if ( $key eq '__ROOT__' );
        $packager->copy_file(qq{$ENV{SDRROOT}/$$map{__ROOT__}/web/$$map{$key}}, basename($$map{$key}), "text/css");
    }

    ## $self->insert_colophon_page($mdpItem, $epub);

    my $title = $mdpItem->GetFullTitle();
    my $root = $mdpItem->_GetMetsRoot();

    # process the contents
    my @filenames = $mdpItem->GetContent('article.primary');
    my @assets = $mdpItem->GetContent('assets.embedded');

    my $updater = new SRV::Utils::Progress 
        filename => $self->progress_filename, total_pages => scalar @filenames + @assets,
        download_url => $self->download_url;
    $updater->initialize;
    $self->updater($updater);

    # process the contents
    my $i = 0;
    foreach my $fileid ( @filenames ) {
        $i += 1;

        my $filename = $mdpItem->GetFileById($fileid);
        my $processor = Process::Article::HTML->new(
            output_filename => $self->working_path . qq{/$filename.html},
            mode => 'static',
            file => $fileid
        );
        my $output = $processor->process($env);
        my $target_filename = basename($$output{filename});
        my $page_title = $processor->processor->dom->findvalue(q{string(//title)}),
        my $nav_idx = $packager->copy_xhtml($$output{filename}, $target_filename);
        $packager->add_navpoint(
            label => $page_title,
            id    => $nav_idx,
            content => $target_filename,
        );
        $self->_track_html_filename($target_filename);

        unless ( $title ) {
            $title = $page_title;
        }

        $updater->update($i);
    }

    foreach my $fileid ( @assets ) {
        $i += 1;        
        my $filename = $mdpItem->GetFileById($fileid);
        my $source_filename = $mdpItem->GetFilePathMaybeExtract($fileid);
        my $source_content_type = $mdpItem->GetStoredFileMimeType($fileid);
        # just copy these
        $packager->copy_file($source_filename, $filename, $source_content_type);
        $updater->update($i);
    }


    # foreach my $fptr ( $assets->get_nodelist ) {
    #     $i += 1;
    #     my $fileid = $fptr->getAttribute('FILEID');
    #     my $filename = $mdpItem->GetFileById($fileid);
    #     my $source_filename = $mdpItem->GetFilePathMaybeExtract($fileid);
    #     my $source_content_type = $mdpItem->GetStoredFileMimeType($fileid);
    #     # just copy these
    #     $packager->copy_file($source_filename, $filename, $source_content_type);
    #     $updater->update($i);
    # }
}

sub _track_html_filename {
    my $self = shift;
    push @{ $self->html_filenames }, @_;
}

1;
