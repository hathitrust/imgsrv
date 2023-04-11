package SRV::Cover;

# use parent qw( SRV::Base );
use parent qw( Plack::Component );

use Plack::Request;
use Plack::Util;
use Plack::Util::Accessor qw(
    id
    file
    size
    format
    missing
    force
    mode
    quality
    restricted
);

use Process::Image;

use Data::Dumper;

use IO::File;

use SRV::Globals;

use Identifier;
use SRV::Utils;
use Utils;

use Scalar::Util;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->mode('cover');
    $self->quality('native') unless ( defined $self->quality );

    $self;
}

sub run {
    my ( $self, $env, %args ) = @_;

    $self->_fill_params($env, \%args);
    $self->_validate_params($env);

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    $self->restricted(0) unless ( Debug::DUtils::under_server() );

    my $restricted = $self->restricted;
    unless ( defined $restricted ) {
        # $restricted = $C->get_object('Access::Rights')->assert_final_access_status($C, $gId) ne 'allow';
        $restricted = $$env{'psgix.restricted'};
    }

    # now we deal with extracting
    my $cache_dir = SRV::Utils::get_cachedir();
    my $logfile = SRV::Utils::get_logfile();

    my $file = $self->file();
    unless ( $file ) {
        return { filename => undef };
    }

    my $source_file_type = $self->format || $mdpItem->GetStoredFileType( $file );
    my $content_type = $SRV::Globals::gTargetMimeTypes{$source_file_type};
    my $output_file_type = $SRV::Globals::gTargetFileTypes{$content_type};

    my $tmpfilename; my $output_filename;
    $output_filename = $self->_build_output_filename($env, $output_file_type);
    $tmpfilename = SRV::Utils::generate_temporary_filename($mdpItem, $output_file_type);

    if ( -f $output_filename && ! $self->force ) {
        # file exists; we're happy
        my ( $width, $height ) = Process::Image::imgsize($output_filename);
        return { filename => $output_filename, mimetype => $content_type,
                 metadata => { width => $width, height => $height } };
    }

    # missing, checkout page sequence
    $source_filename = $mdpItem->GetFilePathMaybeExtract($file, 'imagefile');

    my $max_dimension = $SRV::Globals::gMaxThumbnailSize;

    my $processor = new Process::Image;

    $processor->source( filename => $source_filename);
    $processor->output( filename => $output_filename );
    $processor->tmpfilename($tmpfilename) if ( $tmpfilename );
    $processor->format($content_type);
    $processor->size($self->size);
    $processor->logfile($logfile);
    $processor->restricted($restricted); # until covers really go live
    $processor->max_dim($max_dimension) if ( $max_dimension );
    $processor->quality($self->quality);
    $processor->transformers( $$env{'psgix.image.transformers'} ) if ( defined $$env{'psgix.image.transformers'} );
    # $processor->blank($blank) if ( $blank );

    my $output = $processor->process();
    return $output;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    my $output = $self->run($env);
    unless ( defined $$output{filename} ) {
        my $res = $req->new_response(200);
        my $fh = new IO::File $SRV::Globals::gDefaultCoverPage;
        $res->body($fh);
        return $res->finalize;
    }

    # # record the dimensions
    # $$env{'psgix.choke.image.size'} = ( $$output{metadata}{width} > $$output{metadata}{height }) ? $$output{metadata}{width} : $$output{metadata}{height};

    my $fh = new IO::File $$output{filename};

    my $res = $req->new_response(200);
    $res->content_type($$output{mimetype});
    $res->header('X-HathiTrust-ImageSize' => $$output{metadata}{width} . "x" . $$output{metadata}{height});
    $res->body($fh);
    $res->finalize;
}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my %params = (
        file => undef,
        size => 'full',
        quality => 'native',
        format => undef,
        force => undef,
        id => undef,
    );

    SRV::Utils::parse_env(\%params, [qw(size quality format)], Plack::Request->new($env), $args);

    # LEGACY PARAMETER CHECKS
    my $req = Plack::Request->new($env);
    my $w = $req->param('width');
    my $h = $req->param('height');
    my $res = $req->param('res');
    unless ( $w =~ m,^\d+$, ) { $w = undef; }
    unless ( $h =~ m,^\d+$, ) { $h = undef; }
    unless ( $res =~ m,^\d+$, ) { $res = undef; }
    if ( defined $res ) {
        $params{size} = "res:$res";
    } elsif ( defined $w && defined $h ) {
        $params{size} = qq{!$w,$h};
    } elsif ( defined $w ) {
        $params{size} = qq{$w,};
    } elsif ( defined $h ) {
        $params{size} = qq{,$h};
    }

    foreach my $param ( keys %params ) {
        $self->$param($params{$param});
    }
}

sub _validate_params {
    my ( $self, $env ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    $self->file($mdpItem->GetItemCover());

    $self->_validate_params_size();
    $self->_validate_params_format();
}

sub _validate_params_size {
    my ( $self ) = @_;

    # imgsrv has a noscale=1 parameter --- obsolete?

    unless ( $self->size || $self->size eq 'full' ) {
        # use the default size
        $self->size($self->_default_params_size);
    }

    my $size = $self->size();
    my $is_valid = 0;
    if ( $size =~ m,^\d+$, ) {
        # pt "size" parameter
        unless ( exists( $SRV::Globals::gSizes{$size}) ) {
            foreach my $key ( sort { $a <=> $b } keys %SRV::Globals::gSizes ) {
                if ( $key > $size ) {
                    $size = $key;
                    last;
                }
            }
        }
        $is_valid = 1;
    } elsif ( $size =~ m{^\d+,$} || $size =~ m{^,\d+$} || $size =~ m{pct:\d+} || $size =~ m{^\!?\d+,\d+$} || $size =~ m{res:\d+}, ) {
        $is_valid = 1;
    }

    unless ( $is_valid ) {
        $size = $self->_default_params_size;
    }

    $self->size($size);
}

sub _validate_params_rotation {
    my ( $self ) = @_;
    # only allow for % 90
    my $rotation = $self->rotation;

    unless ( $rotation ) {
        $rotation = 0;
    }

    if ( $rotation =~ m,^orient:, ) {
        # old school
        $rotation =~ s,^orient:,,;
        $rotation = $SRV::Globals::gValidRotationValues{$rotation} || '0';
    }

    $rotation = int($rotation);

    if ( $rotation % 90 > 0 ) {
        # non-90 degree turn
        $rotation = 0;
    } elsif ( $rotation == 360 ) {
        $rotation = 0;
    }

    $self->rotation($rotation);
}

sub _validate_params_format {
    my ( $self ) = @_;
    my $format = $self->format;
    if ( $format && $format =~ m,image/, ) {
        # looks like a mime type, so make it a suffix
        $self->format($SRV::Globals::gTargetFileTypes{$format});
    }

}

sub _build_output_filename {
    my $self = shift;
    my $env = shift;
    my $ext = shift;
    my $output_filename =
        SRV::Utils::generate_output_filename($env, [ $self->file, $self->mode, 'full', $self->size, '0', $self->quality, $self->restricted, 'ZZZ' ], $ext);
    return $output_filename;
}

sub _default_params_size {
    my $self = shift;
    ## are these 80px _side_ or fit an 80x80 box?
    return ",80";
    # if ( $self->mode eq 'thumbnail' ) {
    #     return qq{!$SRV::Globals::gDefaultThumbnailSize,$SRV::Globals::gDefaultThumbnailSize};
    # }
    # return $SRV::Globals::gDefaultSize;
}

sub _get_fileid {
    my $self = shift;
    my $file = $self->file;
    if ( $file =~ m,^seq:, ) {
        $file =~ s,^seq:,,;
    }
    return $file;
}

sub _seq_from_file {
    my $self = shift;
    my $file = $self->file;
    my $seq = (split(/:/, $file))[-1];
    return $seq;
}

1;
