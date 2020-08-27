package Process::Article::EPUB;

use parent qw( Process::Article::Base );

use Process::Globals;

use EBook::EPUB;
use Builder;

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);

}

sub process {
    my $self = shift;
    my $env = shift;

    my $packager = EBook::EPUB->new;
    $self->gather_files($env, $packager);
    $self->generate_epub($packager);
    $self->updater->finish();

    return {
        filename => $self->output_filename,
        mimetype => 'application/zip+epub',
    }
}

sub generate_epub {
    my ( $self, $packager ) = @_;

    # this isn't actually used yet
    $packager->copy_file("$Process::Globals::static_path/epub/stylesheet.css", "stylesheet.css", "text/css");

    $packager->add_title($self->mdpItem->GetFullTitle());
    $packager->add_author($self->mdpItem->GetAuthor());
    #$epub->add_language('en');
    $packager->add_identifier($self->mdpItem->GetId(), 'HathiTrust');

    $packager->pack_zip($self->output_filename);
}


1;