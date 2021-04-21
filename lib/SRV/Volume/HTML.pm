package SRV::Volume::HTML;

# use parent qw( SRV::Base );
use parent qw( Plack::Component );

use Plack::Request;
use Plack::Util;
use Plack::Util::Accessor qw( file mode restricted p output_filename q1 );

use Process::Text;

use Data::Dumper;

use IO::File;

use SRV::Globals;

use Identifier;
use SRV::Utils;
use Utils;

use Scalar::Util;
use File::Basename qw(basename);

use SRV::SearchUtils;

use utf8;
use Encode qw(encode_utf8);

our $content_type = q{text/html};

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->mode('standalone') unless ( $self->mode );

    $self;
}

sub run {
    my ( $self, $env, %args ) = @_;

    $self->_fill_params($env, \%args) if ( %args );
    $self->_validate_params($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    if ( ! $mdpItem->Get('has_ocr') ) {
        # there's no OCR in this volume
        return { contents => "<div></div>", mimetype => 'text/html' };
    }

    $self->restricted(0) unless ( Debug::DUtils::under_server() );

    my $restricted = $self->restricted;
    unless ( defined $restricted ) {
        # $restricted = $C->get_object('Access::Rights')->assert_final_access_status($C, $gId) ne 'allow';
        $restricted = $$env{'psgix.restricted'};
    }

    # now we deal with extracting
    my $cache_dir = SRV::Utils::get_cachedir();
    my $logfile = SRV::Utils::get_logfile();

    my $file = $self->_get_fileid();
    if ( $file =~ m,^\d+$, ) {
        # looks like a seq
        $file = $mdpItem->GetValidSequence($file);
    }

    my $ocr_filename_path = $mdpItem->GetFilePathMaybeExtract($file, 'ocrfile');
    my $ocr_filename = $mdpItem->GetFileNameBySequence($file, 'ocrfile');

    my $html_filename_path;
    my $html_filename = $mdpItem->GetFileNameBySequence($file, 'coordOCRfile');

    my %words = ();
    if ( $self->q1 ) {
        my $seq = $self->_get_fileid;
        my $solrTextRef = SRV::SearchUtils::Solr_retrieve_OCR_page($C, $gId, $mdpItem->GetPhysicalPageSequence($seq));

        ## -- for when we decide to do multiple search term highlighting
        ## my @retval = ( $text =~ m,(\{lt:\}strong[^\{].*?\{gt:\}.*?\{lt:\}/strong\{gt:\}),gsm );
        %words = map { lc $_ => 1 } ( $$solrTextRef =~ m,\{lt:\}strong[^\{].*?\{gt:\}(.*?)\{lt:\}/strong\{gt:\},gsm );
    }

    # currently does not cache
    my $p = new Process::Text;
    $p->output(mimetype => 'text/html');
    $p->fragment(1);
    $p->missing(1) if ( grep(/MISSING_PAGE/, $mdpItem->GetPageFeatures($file)) );
    $p->missing(1) unless ( $ocr_filename );
    $p->restricted(1) if ( $restricted );
    $p->readingOrder($mdpItem->Get('readingOrder'));

    if ( $html_filename ) {
        $html_filename_path = $mdpItem->GetFilePathMaybeExtract($file, 'coordOCRfile');
        $p->source(filename => $html_filename_path);
    } else {
        $p->source(filename => $ocr_filename_path);
    }

    my $target = $p->process();

    # missing, checkout page sequence
    my $page_info = $mdpItem->{ 'pageinfo' };
    my $source_filename;
    # if ( grep(/MISSING_PAGE/, $mdpItem->GetPageFeatures($file)) ) {
    #     $source_filename = $SRV::Globals::gMissingPageImage;
    # } else {
    #    $source_filename = $mdpItem->GetFilePathMaybeExtract($file, 'imagefile');
    # }

    my $blank = 0;
    if ( grep(/CHECKOUT_PAGE/, $mdpItem->GetPageFeatures($file)) ) {
        # this should be a blank page
        $blank = 1;
    }

    if ( scalar keys %words ) {
        my $words = JSON::XS::encode_json([keys %words]);
        # then decode this so it can be properly slotted into the text
        utf8::decode($words);
        $$target{contents} =~ s,<div,<div data-words='$words' ,;
    }
    return $target;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    $self->_fill_params($env);
    $self->_validate_params($env);

    my $target = $self->run($env);

    my $res = $req->new_response(200);
    $res->content_type($$target{mimetype} . ";charset=utf-8");

    my $contents = encode_utf8($$target{contents});
    # utf8::downgrade($contents);
    $res->body($contents);
    $res->finalize;
}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    my $req = Plack::Request->new($env);
    my %params = (
        file => undef,
        mode => $self->mode,
        output_filename => undef,
        q1 => undef
    );

    SRV::Utils::parse_env(\%params, [qw(file mode)], $req, $args);

    foreach my $param ( keys %params ) {
        $self->$param($params{$param});
    }
}

sub _validate_params {
    my ( $self, $env ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    unless ( $self->file ) {
        # assume it's the default seq
        my $seq;
        $seq = $mdpItem->HasTitleFeature();
        unless ( $seq ) {
            $seq = $mdpItem->HasTOCFeature();
        }
        $self->file("seq:$seq");
    }

    # my $output_filename = $self->output_filename;
    # unless ( $output_filename ) {
    #     my $cache_dir = SRV::Utils::get_cachedir();
    #     my $output_pathname =
    #         $cache_dir . Identifier::id_to_mdp_path($gId) . "_" . $mdpItem->get_modtime();
    #     Utils::mkdir_path( $output_pathname, $SRV::Globals::gMakeDirOutputLog );

    #     $output_filename = $output_pathname . q{/} . $self->file . q{-} . $self->mode . q{.html};
    #     $self->output_filename($output_filename);
    # }

}

sub _get_fileid {
    my $self = shift;
    my $file = $self->file;
    if ( $file =~ m,^seq:, ) {
        $file =~ s,^seq:,,;
    }
    return $file;
}

1;
