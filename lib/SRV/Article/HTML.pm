package SRV::Article::HTML;

# use parent qw( SRV::Base );
use parent qw( Plack::Component );

use Plack::Request;
use Plack::Util;
use Plack::Util::Accessor qw( file mode restricted p output_filename );

use Process::Article::HTML;

use Data::Dumper;

use IO::File;

use SRV::Globals;

use Identifier;
use SRV::Utils;
use Utils;

use Scalar::Util;
use File::Basename qw(basename);

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

    unless ( defined $self->restricted ) {
        my $restricted = $C->get_object('Access::Rights')->assert_final_access_status($C, $gId) ne 'allow';
        $self->restricted($restricted);
    }

    my $processor = Process::Article::HTML->new(
        mdpItem => $mdpItem,
        output_filename => $self->output_filename,
        mode => $self->mode,
        file => $self->file,
    );

    my $output = $processor->process($env);
    return $output;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    $self->_fill_params($env);
    $self->_validate_params($env);

    if ( ! -f $self->output_filename || $req->param('force') ) {
        $self->run($env);
    }

    unless ( -f $self->output_filename ) {
        my $res = $req->new_response(404);
        $res->body("NOT FOUND");
        return $res->finalize;
    }

    my $fh = new IO::File $self->output_filename;

    my $res = $req->new_response(200);
    $res->content_type($content_type);
    $res->body($fh);
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

    # select the first primary article
    unless ( defined $self->file ) {
        my @fileids = $mdpItem->GetContent('article.primary');
        $self->file($fileids[0]);
    }

    my $output_filename = $self->output_filename;
    unless ( $output_filename ) {
        my $cache_dir = SRV::Utils::get_cachedir();
        my $output_pathname =
            $cache_dir . Identifier::id_to_mdp_path($gId) . "_" . $mdpItem->get_modtime();
        Utils::mkdir_path( $output_pathname, $SRV::Globals::gMakeDirOutputLog );

        $output_filename = $output_pathname . q{/} . $self->file . q{-} . $self->mode . q{.html};
        $self->output_filename($output_filename);
    }

}

1;