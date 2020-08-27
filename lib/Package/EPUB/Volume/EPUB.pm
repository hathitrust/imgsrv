package Package::EPUB::Volume::EPUB;

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
);

use IPC::Run qw();

sub generate {
    my $self = shift;
    $self->updater->update(0);

    my $mdpItem = $self->mdpItem;

    # extract to the working dir
    my $working_dir = $self->working_dir;

    my $fileid = $mdpItem->GetPackageId();
    my $epub_filename = $mdpItem->GetFilePathMaybeExtract($fileid, 'epubfile');
    print STDERR "AHOY UNPACKING $epub_filename\n";

    my @unzip;
    my @yes;
    push @yes, "echo", "n";
    my $UNZIP_PROG = "/l/local/bin/unzip";
    push @unzip, $UNZIP_PROG,"-qq", "-d", $working_dir, $epub_filename;
    IPC::Run::run \@yes, '|',  \@unzip, ">", "/dev/null", "2>&1";

    $self->updater->finish();

    return 1;
}

sub viewport {
    my $self = shift;
    return undef;
}

sub additional_message {
    my $self = shift;
    my ( $xml ) = @_;
    '';
}

1;