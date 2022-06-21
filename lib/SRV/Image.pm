package SRV::Image;

# use parent qw( SRV::Base );
use parent qw( Plack::Component );

use Plack::Request;
use Plack::Util;
use Plack::Util::Accessor qw(
    id
    mode
    file
    size
    region
    rotation
    quality
    format
    mimetype
    restricted
    watermark
    default_watermark
    missing
    force
    tracker
);

use Process::Image;

use Data::Dumper;

use IO::File;
use JSON::XS;

use SRV::Globals;

use Identifier;
use SRV::Utils;
use Utils;

use Scalar::Util;

use Cwd ();

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->mode('image') unless ( $self->mode );
    $self->watermark(1) unless ( defined $self->watermark );
    $self->default_watermark($self->watermark);
    $self->quality('default') unless ( defined $self->quality );

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
        ## $self->restricted($restricted);
    }

    # now we deal with extracting
    my $cache_dir = SRV::Utils::get_cachedir();
    my $logfile = SRV::Utils::get_logfile();

    my $file = $self->_get_fileid();
    if ( $file =~ m,^\d+$, ) {
        # looks like a seq
        $file = $mdpItem->GetValidSequence($file);
        $self->file("seq:$file");
    }

    my @features = $mdpItem->GetPageFeatures($file);
    my $source_file_type = $self->format || $mdpItem->GetStoredFileType( $file );
    my $source_file_type = $mdpItem->GetStoredFileType( $file );
    if ( ! $source_file_type ) { push @features, 'MISSING_PAGE'; $source_file_type = 'jpg'; }

    my ( $content_type, $output_file_type ) = ( $self->mimetype, $self->format );
    unless ( $content_type ) {
        $content_type = $SRV::Globals::gTargetMimeTypes{$source_file_type};
        $output_file_type = $SRV::Globals::gTargetFileTypes{$content_type};
    }

    my $tmpfilename; my $output_filename;

    if ( ! $restricted && $C->get_object('Access::Rights')->in_copyright($C, $gId) ) {
        my $role = $$env{'X-ENV-ROLE'} || Auth::ACL::a_GetUserAttributes('role');
        if ( $role ) {
            $output_filename = $self->_build_output_filename_by_role($env, $role, $output_file_type);
            my $test_output_filename = $output_filename;
            if ( ! -f $output_filename && Debug::DUtils::under_server() ) { $output_filename = undef; }
        }
    }
    $output_filename = $self->_build_output_filename($env, $restricted, $output_file_type) unless ( $output_filename );
    my $metadata_filename = SRV::Utils::generate_output_filename($env, [ $self->file ], 'json');

    if ( -f $output_filename && ! $self->force ) {
        # file exists; we're happy
        my ( $width, $height ) = Process::Image::imgsize($output_filename);
        my $source_metadata = {};
        if ( -s $metadata_filename ) {
            eval {
                open(my $fh, "<", $metadata_filename);
                $source_metadata = do { local $/; <$fh> };
                close($fh);
                $source_metadata = decode_json($source_metadata);
            };
            if ( my $err = $@ ) {
                print STDERR "could not open source metadata - $err\n";
            }
        }
        return { filename => $output_filename, mimetype => $content_type,
                 metadata => { width => $width, height => $height },
                 source_metadata => $source_metadata };
    }

    $tmpfilename = SRV::Utils::generate_temporary_filename($mdpItem, $output_file_type);

    # missing, checkout page sequence
    my $page_info = $mdpItem->{ 'pageinfo' };
    my $source_filename;
    if ( $self->missing || grep(/MISSING_PAGE/, @features) ) {
        $source_filename = $SRV::Globals::gMissingPageImage;
    } else {
       $source_filename = $mdpItem->GetFilePathMaybeExtract($file, 'imagefile');
    }

    my $blank = 0;
    if ( grep(/CHECKOUT_PAGE/, @features) ) {
        # this should be a blank page
        $blank = 1;
    }

    my $max_dimension = SRV::Utils::get_max_dimension($mdpItem);
    if ( $self->mode eq 'thumbnail' ) {
        $max_dimension = $SRV::Globals::gMaxThumbnailSize;
    }

    my $processor = new Process::Image;

    $processor->mdpItem($mdpItem);
    $processor->source( filename => $source_filename);
    $processor->output( filename => $output_filename );
    $processor->tmpfilename($tmpfilename) if ( $tmpfilename );
    $processor->format($content_type);
    $processor->size($self->size);
    $processor->region($self->region);
    $processor->rotation($self->rotation);
    $processor->logfile($logfile);
    $processor->watermark($self->watermark);
    $processor->restricted($restricted);
    $processor->max_dim($max_dimension) if ( $max_dimension );
    $processor->quality($self->quality);
    $processor->blank($blank) if ( $blank );

    my $output = $processor->process();

    $self->_maybe_cache_source_metadata($output, $metadata_filename);

    return $output;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    my $output = $self->run($env);

    my $max_age = 86400;    # 1 day = 60 * 60 * 24
    my $cache_control = qq{max-age=$max_age};

    unless ( $$output{data} || $$output{filename} ) {
        my $res = $req->new_response(404);
        $res->body("NOT FOUND");
        return $res->finalize;
    }

    if ( $$output{restricted} ) {
        $cache_control = 'no-cache';
    }

    # my $fh = $$output{data} || new IO::File $$output{filename};
    my $fh;
    if ( $$output{data} ) {
        $fh = $$output{data};
    } else {
        open $fh, "<:raw", $$output{filename};
        Plack::Util::set_io_path($fh, Cwd::realpath($$output{filename}));
    }

    my $res = $req->new_response(200);
    $res->content_type($$output{mimetype});
    $res->header('X-HathiTrust-ImageSize' => $$output{metadata}{width} . "x" . $$output{metadata}{height});

    if ( exists $$output{source_metadata}{XResolution} ) {
        my $image_res = $$output{source_metadata}{XResolution};
        my $image_units = $$output{source_metadata}{ResolutionUnit} // 'inches';
        $image_units = 'dpi' if ( $image_units eq 'inches' );
        $res->header('X-Image-Resolution' => "$image_res $image_units");
    }
    if ( exists $$output{source_metadata}{width} ) {
        $res->header('X-Image-Size' => $$output{source_metadata}{width} . "x" . $$output{source_metadata}{height});
    }
    $res->header('X-HathiTrust-Access' => $$output{restricted} ? 'deny' : 'allow');

    $res->header('Content-length', -s $$output{filename});
    $res->header('Cache-Control', "$cache_control, private");

    unless ( $$env{REMOTE_USER} ) {
        # add CORS headers to anonymous requests
        $res->header('Access-Control-Allow-Origin', '*');
    }

    my $attachment_filename = $self->_build_attachment_filename($output);
    my $disposition = $req->param('attachment') eq '1' ? "attachment" : "inline";
    $res->header('Content-disposition', qq{$disposition; filename=$attachment_filename});

    if ( $self->tracker ) {
        my $value = $req->cookies->{tracker} || '';
        $res->cookies->{tracker} = {
            value => $value . $self->tracker,
            path => '/',
            expires => time + 24 * 60 * 60,
        };
    }

    $res->body($fh);
    $res->finalize;
}

sub _maybe_cache_source_metadata {
    my ( $self, $output, $metadata_filename ) = @_;
        # cache the source metadata
    if ( exists $$output{source_metadata}{XResolution} ) {
        my $metadata = { %{ $$output{source_metadata} } };
        foreach my $key ( keys %$metadata ) {
            if ( ref($$metadata{$key}) eq 'Image::TIFF::Rational' ) {
                $$metadata{$key} = $$metadata{$key}->as_float;
            }
        }
        eval {
            open(my $fh, ">", $metadata_filename);
            print $fh encode_json($metadata);
            close($fh);
        };
        if ( my $err = $@ ) {
            print STDERR "could not write to $metadata_filename : $err\n";
        }
    }
}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my %params = (
        file => undef,
        region => 'full',
        size => 'full',
        rotation => '0',
        quality => 'default',
        format => undef,
        force => undef,
        id => undef,
        tracker => undef,
    );

    if ( $ENV{PSGI_COMMAND} ) {
        $params{watermark} = $self->default_watermark;
    }

    SRV::Utils::parse_env(\%params, [qw(file region size rotation quality format)], Plack::Request->new($env), $args);

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

    my $o = $req->param('orient');
    if ( defined $o && $o =~ m,^\d+, ) {
        $params{rotation} = qq{orient:$o};
    }

    foreach my $param ( keys %params ) {
        $self->$param($params{$param});
    }
}

sub _validate_params {
    my ( $self, $env ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    unless ( $self->file ) {
        # assume it's the default seq
        my $seq;
        $seq = $mdpItem->HasTitleFeature();
        unless ( $seq ) {
            $seq = $mdpItem->HasTOCFeature();
            unless ( $seq ) {
                $seq = 1;
            }
        }
        $self->file("seq:$seq");
    }

    $self->_validate_params_size();
    # $self->_validate_params_region();
    $self->_validate_params_rotation();
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
    } elsif ( $size eq 'full' || $size =~ m{^\d+,$} || $size =~ m{^,\d+$} || $size =~ m{pct:\d+} || $size =~ m{^\!?\d+,\d+$} || $size =~ m{res:\d+} || $size =~ m{ppi:\d+$} ) {
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
        $self->mimetype($format);
        $self->format($SRV::Globals::gTargetFileTypes{$format});
    } else {
        $self->mimetype($SRV::Globals::gTargetMimeTypes{$format});
    }

}

sub _build_output_filename {
    my $self = shift;
    my $env = shift;
    my $restricted = shift || 0;
    my $ext = shift;
    my $output_filename =
        SRV::Utils::generate_output_filename($env, [ $self->file, $self->mode, $self->region, $self->size, $self->rotation, $self->quality, $restricted, $self->watermark ], $ext);
    return $output_filename;
}

sub _build_output_filename_by_role {
    my $self = shift;
    my $env = shift;
    my $role = shift; # as of 2020-08, we're not using $role in the filename options array
    my $ext = shift;
    my $restricted = 0;
    my $output_filename =
        SRV::Utils::generate_output_filename($env, [ $self->file, $self->mode, $self->region, $self->size, $self->rotation, $self->quality, $restricted, $self->watermark ], $ext, $role);
    return $output_filename;
}

sub _build_attachment_filename {
    my $self = shift;
    my ( $output ) = @_;
    my $filename = join('-', $self->id, $self->file) . '.' . $SRV::Globals::gTargetFileTypes{$$output{mimetype}};
    $filename =~ s,[^\w\.-],_,g;
    return $filename;
}

sub _default_params_size {
    my $self = shift;
    if ( $self->mode eq 'thumbnail' ) {
        return qq{!$SRV::Globals::gDefaultThumbnailSize,$SRV::Globals::gDefaultThumbnailSize};
    }
    return $SRV::Globals::gDefaultSize;
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
