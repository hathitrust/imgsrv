package SRV::Utils;

use Context;
use Utils::Extract;
use Utils;
use Identifier;
use POSIX qw/strftime/;
use Access::Statements;
use Utils::Logger;
use Utils::Time;
use File::Pairtree;

use SRV::Globals;

use Scalar::Util;

use Time::HiRes qw();

use File::Temp qw(tempdir);

use Digest::MD5;
use IPC::Run;

our @watermark_config;

sub under_server {
    return ( ! defined $ENV{PSGI_COMMAND} );
}

sub generate_temporary_filename
{
    my $mdpItem = shift;
    my $outputFileType = shift || 'dat';

    # write tmp to $cachedir ... but $cachedir won't clean up tmp files immediately
    ### return get_cachedir() . "/$$.$outputFileType";
    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($mdpItem->GetId());
    return Utils::Extract::__get_tmpdir($stripped_pairtree_id) . "/$$.$outputFileType";
}

sub generate_temporary_dirname
{
    my $mdpItem = shift;
    my $suffix = shift;
    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($mdpItem->GetId());
    return Utils::Extract::__get_tmpdir($stripped_pairtree_id, $suffix);
}

# ----------------------------------------------------------------------

=item __get_cachedir_root

Description

=cut

# ---------------------------------------------------------------------

sub get_cachedir
{
    my $C = new Context;
    my $key = shift || 'imgsrv_cache_dir';

    my $cache_dir = Utils::get_true_cache_dir($C, $key);
    return $cache_dir . '/';
}

sub seq2range
{
    my ( $seqlist ) = @_;
    my $rangelist = [];
    foreach my $seq ( @{ $seqlist } ) {
        if ( scalar @$rangelist == 0 ) {
            push @$rangelist, [ $seq, -1 ];
        } elsif ( $seq - $$rangelist[-1][1] == 1 ) {
            $$rangelist[-1][1] = $seq;
        } elsif ( $seq - $$rangelist[-1][0] == 1 ) {
            $$rangelist[-1][1] = $seq;
        } else {
            push @$rangelist, [ $seq, -1 ];
        }
    }

    foreach my $idx ( 0 .. ( scalar @$rangelist - 1 ) ) {
        my $tmp = $$rangelist[$idx];
        if ( $$tmp[1] < 0 ) {
            $$rangelist[$idx] = $$tmp[0];
        } else {
            $$rangelist[$idx] = join('-', @$tmp);
        }
    }
    return $rangelist;
}

sub range2seq
{
    my ( $rangelist ) = @_;
    my @tmp = ();
    unless ( ref($rangelist) ) {
        $rangelist = [ split(/,/, $rangelist) ];
    }
    foreach my $seq ( @$rangelist ) {
        if ( $seq =~ m,\-, ) {
            my ( $a, $b ) = split(/\-/, $seq);
            while ( $a <= $b ) {
                push @tmp, $a;
                $a += 1;
            }
        } else {
            push @tmp, $seq;
        }
    }
    return [ @tmp ];
}

sub get_download_url
{
    my $service = shift;
    my $action = shift;

    my $C = new Context;

    my $download_url;
    my $id = $C->get_object('MdpItem')->GetId();
    my $auth = $C->get_object('Auth', 1);
    $download_url = '/cgi/';
    $download_url .= qq{imgsrv/download/$action};
    $download_url .= qq{?id=$id};

    if ( my @params = $service->_download_params ) {
        foreach my $p ( @params ) {
            $download_url .= ";$$p[0]=$$p[1]";
        }
    }

    if ( $service->is_partial && scalar @{ $service->pages } ) {
        my $seqlist = seq2range($service->pages);

        foreach my $seq ( @$seqlist ) {
            $download_url .= ";seq=" . $seq;
        }
    }

    $download_url .= ';marker=' . $service->marker;
    $download_url .= ';attachment=1';
    return $download_url;
}

sub get_download_status_url
{
    my $service = shift;
    my $action = shift;

    my $C = new Context;

    my $download_url;
    my $id = $C->get_object('MdpItem')->GetId();
    my $auth = $C->get_object('Auth', 1);
    $download_url = '/cgi/';
    $download_url .= qq{imgsrv/download-status};
    $download_url .= qq{?id=$id};

    if ( $service->is_partial && scalar @{ $service->pages } ) {
        my $seqlist = seq2range($service->pages);
        foreach my $seq ( @$seqlist ) {
            $download_url .= ";seq=$seq";
        }
    }

    $download_url .= ';marker=' . $service->marker;
    return $download_url;
}

sub get_download_progress_base
{
    my $C = new Context;
    my $cache_dir = Utils::get_true_cache_dir($C, 'download_progress_base');
    return $cache_dir . '/';
}

sub get_logfile
{
    my $C = new Context;
    my $config = $C->get_object('MdpConfig');
    my $logfile = Utils::get_tmp_logdir() . "/" . $config->get('imgsrv_logfile');
    my $today = strftime("%Y-%m-%d", localtime());
    $logfile =~ s!\.log!-$today.log!;
    $logfile .= ".$ENV{SERVER_ADDR}";

    chmod(0666, $logfile) if (-o $logfile);

    return $logfile;
}

sub log_message
{
    my $logfile = get_logfile();
    open(LOG, ">>", $logfile);
    print LOG @_, "\n";
    close(LOG);
}

sub log_string
{
    my ( $logfile, $tuples ) = @_;
    my $C = new Context;
    my $mdpItem = $C->get_object('MdpItem');

    # # we want the collection and digitization sources, but these are not available directly...
    # my ( $digitization_source, $collection_source ) = get_sources($mdpItem);
    # push @$tuples, ['digitization', $digitization_source];
    # push @$tuples, ['collection', $collection_source];

    # # see lament in Auth::Logging
    # my $pattern = qr(slip/run-___RUN___|___QUERY___);
    # Utils::Logger::__Log_string($C, $s, qq{imgsrv_${logfile}_logfile}, $pattern, 'imgsrv');

    Auth::Logging::log_access($C, 'imgsrv', $tuples, {postfix => $logfile});
}

sub log_string_xxx
{
    my ( $logfile, $s ) = @_;
    my $C = new Context;
    my $mdpItem = $C->get_object('MdpItem');
    my $auth = $C->get_object('Auth');
    my $ar = $C->get_object('Access::Rights');

    my $id                    = $mdpItem->GetId();
    my $ic                    = $ar->in_copyright($C, $id) || 0;
    my $access_type           = $ar->get_access_type($C, 'as_string');
    my $remote_addr           = $ENV{REMOTE_ADDR} || 'notset';
    my $remote_user_processed = Utils::Get_Remote_User() || 'notset';
    my $remote_user_from_env  = $ENV{REMOTE_USER} || 'notset';
    my $proxied_addr          = Access::Rights::proxied_address() || 'notset';
    my $auth_type             = lc ($ENV{AUTH_TYPE} || 'notset');
    my $http_host             = $ENV{HTTP_HOST} || 'notset';
    my $inst_code             = $auth->get_institution_code($C) || 'notset';
    my $rights_attribute      = $ar->get_rights_attribute($C, $id) || 'notset';
    my $source_attribute      = $ar->get_source_attribute($C, $id) || 'notset';

    # we want the collection and digitization sources, but these are not available directly...
    my ( $digitization_source, $collection_source ) = get_sources($mdpItem);

    my ($usertype, $role) = (
                             Auth::ACL::a_GetUserAttributes('usertype') || 'notset',
                             Auth::ACL::a_GetUserAttributes('role') || 'notset',
                            );
    my $datetime = Utils::Time::iso_Time();
    $s .= qq{|id=$id|datetime=$datetime|attr=$attr|ic=$ic|access_type=$access_type|digitization=$digitization_source|collection=$collection_source|remote_addr=$remote_addr|proxied_addr=$proxied_addr|remote_user_env=$remote_user_from_env|remote_user_processed=$remote_user_processed|auth_type=$auth_type|usertype=$usertype|role=$role|sdrinst=$sdrinst|sdrlib=$sdrlib|http_host=$http_host|inst_code=$inst_code};

    if ($auth_type eq 'shibboleth') {
        my $affiliation = $ENV{affiliation} || 'notset';
        my $eppn = $ENV{eppn} || 'notset';
        my $display_name = $ENV{displayName} || 'notset';
        my $entityID = $ENV{Shib_Identity_Provider} || 'notset';
        my $persistent_id = $ENV{persistent_id} || 'notset';

        $s .= qq{|eduPersonScopedAffiliation=$affiliation|eduPersonPrincipalName=$eppn|displayName=$display_name|persistent_id=$persistent_id|Shib_Identity_Provider=$entityID};
    }

    # see lament in Auth::Logging
    my $pattern = qr(slip/run-___RUN___|___QUERY___);
    Utils::Logger::__Log_string($C, $s, qq{imgsrv_${logfile}_logfile}, $pattern, 'imgsrv');
}

sub __get_cachedir_root
{
    return $ENV{'SDRROOT'};
}

sub get_watermark_filename
{
    my ( $mdpItem, $sizing, $suffix ) = @_;

    unless ( $SRV::Globals::gWatermarkingEnabled ) {
        return ();
    }

    my $id = ref($mdpItem) ? $mdpItem->GetId() : $mdpItem;

    my ( $digitization_source, $collection_source ) = get_sources($mdpItem);

    return () unless ( $digitization_source || $collection_source );

    unless ( ref $sizing ) {
      $sizing = { size => 100 };
    }

    my $size; my $base_size = 680;
    if ( exists $$sizing{size} && exists $SRV::Globals::gWatermarkSizes{$$sizing{size}} ) {
        $size = $$sizing{size};
    } elsif ( exists $$sizing{width} ) {
        foreach my $size_ ( sort { int($b) <=> int($a) } keys %SRV::Globals::gWatermarkSizes ) {
            my $width = int($base_size * $SRV::Globals::gWatermarkSizes{$size_});
            $size = $size_;
            if ( $width <= $$sizing{width} ) {
                last;
            }
        }
    }

    my @watermark_basenames = ( undef, undef );

    if ( $digitization_source ) {
        if ( -f "$SRV::Globals::gWatermarksDir$digitization_source/digitization/$size.png" ) {
            $watermark_basenames[0] = "$SRV::Globals::gWatermarksDir$digitization_source/digitization/$size";
        } else {
            print STDERR "NOT FOUND : $SRV::Globals::gWatermarksDir$digitization_source/digitization/$size.png\n";
        }
    }
    if ( $collection_source ) {
        if ( -f "$SRV::Globals::gWatermarksDir$collection_source/collection/$size.png" ) {
            $watermark_basenames[1] = "$SRV::Globals::gWatermarksDir$collection_source/collection/$size";
        } else {
            print STDERR "NOT FOUND : $SRV::Globals::gWatermarksDir$collection_source/collection/$size.png\n";
        }
    }

    return @watermark_basenames;
}

sub get_sources
{
    my ( $mdpItem ) = @_;

    my $digitization_source = lc $mdpItem->Get('digitization_source');
    my $collection_source = lc $mdpItem->Get('collection_source');

    # no collection source in METS, punt to using namespace + source attribute lookup
    # NOTE: REMOVE AFTER METS UPLIFT - ROGER
    unless ( $collection_source ) {
        my $C = new Context;
        my $id = $mdpItem->GetId();
        my $rights = $C->get_object('Access::Rights',1);
        my $source_attribute;
        if (ref $rights){
            $source_attribute = $rights->get_source_attribute($C, $id);
        }
        my $namespace = Identifier::the_namespace( $id );
        # get the data from the config file
        unless ( scalar @watermark_config ) {
            @watermark_config = File::Slurp::read_file($SRV::Globals::watermark_config_filename);
        }
        my ( $line ) = grep(/^$namespace\|$source_attribute\|/, @watermark_config); chomp $line;
        return () unless ( $line ); # no watermark found
        my @config = split(/\|/, $line);
        $digitization_source = $config[2];
        $collection_source = $config[3];
    }

    return ( $digitization_source, $collection_source );
}

sub get_max_dimension
{
    my ( $mdpItem ) = @_;

    my $C = new Context;
    my $rights = $C->get_object('Access::Rights',1);
    my $source_attribute;
    if (ref $rights){
        $source_attribute = $rights->get_source_attribute($C, $mdpItem->GetId());
    }

    my $namespace = Identifier::the_namespace( $mdpItem->GetId() );

    my $maxDimension;
    if ( exists($SRV::Globals::gMaxDimensions{$namespace}) ) {
        if ( exists($SRV::Globals::gMaxDimensions{$namespace}{$source_attribute}) ) {
            $maxDimension = $SRV::Globals::gMaxDimensions{$namespace}{$source_attribute};
        }
    }
    return $maxDimension;
}

sub get_itemhandle
{
    my $mdpItem = shift;
    my $id = shift || $mdpItem->GetId( );

    my $href = $SRV::Globals::gHandleLinkStem . $id;

    return $href;
}

sub get_access_statements
{
    my ( $mdpItem ) = @_;
    my $C = new Context;
    my $id = $mdpItem->GetId();
    my $ar = $C->get_object('Access::Rights');
    my $attr = $ar->get_rights_attribute($C, $id);
    my $access_profile = $ar->get_access_profile_attribute($C, $id);

    my $ref_to_arr_of_hashref =
      Access::Statements::get_stmt_by_rights_values($C, undef, $attr, $access_profile,
                                                  {
                                                   stmt_url      => 1,
                                                   stmt_url_aux  => 1,
                                                   stmt_head     => 1,
                                                   stmt_icon     => 1,
                                                   stmt_icon_aux => 1,
                                                   stmt_text     => 1,
                                                  });

    return $ref_to_arr_of_hashref->[0];

}

sub get_feature_map
{
    my ( $mdpItem ) = @_;
    # feature contents
    my $map = {};
    $mdpItem->InitFeatureIterator();
    my $featureRef;

    my $seenFirstTOC = 0;
    my $seenFirstIndex = 0;
    my $seenSection = 0;

    my $i = 1;
    while ($featureRef = $mdpItem->GetNextFeature(), $$featureRef) {
        my $tag   = $$$featureRef{'tag'};
        my $label = $$$featureRef{'label'};
        my $page  = $$$featureRef{'pg'};
        my $seq   = $$$featureRef{'seq'};

        if  ($tag =~ m,FIRST_CONTENT_CHAPTER_START|1STPG,) {
            $label = qq{$label } . $i++;
            $seenSection = 1;
        }
        elsif ($tag =~ m,^CHAPTER_START$,) {
            $label = qq{$label } . $i++;
            $seenSection = 1;
        }
        elsif ($tag =~ m,^MULTIWORK_BOUNDARY$,) {
            # Suppress redundant link on MULTIWORK_BOUNDARY seq+1
            # if its seq matches the next CHAPTER seq.
            my $nextFeatureRef = $mdpItem->PeekNextFeature();
            if ($$nextFeatureRef
                && (
                    ($$$nextFeatureRef{'tag'} =~ m,^CHAPTER_START$,)
                    &&
                    ($$$nextFeatureRef{'seq'} eq $seq))
               ) {
                # Skip CHAPTER_START
                $mdpItem->GetNextFeature();
            }
            $label = qq{$label } . $i++;
            $seenSection = 1;
        }

        if ($seenSection) {
            $seenFirstTOC = 0;
            $seenFirstIndex = 0;
        }

        # Repetition suppression
        if  ($tag =~ m,TABLE_OF_CONTENTS|TOC,) {
            $seenSection = 0;
            if ($seenFirstTOC) {
                next;
            }
            else {
                $seenFirstTOC = 1;
            }
        }

        if  ($tag =~ m,INDEX|IND,) {
            $seenSection = 0;
            if ($seenFirstIndex) {
                next;
            }
            else {
                $seenFirstIndex = 1;
            }
        }

        $$map{$seq} = [ $label, $page ];
    }

    return $map;
}

sub parse_env {
    my ( $params, $path_info_segments, $req, $args )  = @_;
    if ( Scalar::Util::blessed($req) ) {

        # foreach my $key ( keys %{ $req->env } ) {
        #     print STDERR "ENV : $key : " . $req->env->{$key} . "\n";
        # }

        my $mdpItem = $req->env->{'psgix.context'}->get_object('MdpItem');
        my $id = $mdpItem->GetId();

        if ( exists $params{id} ) {
            # fill with the mdpItem
            $$params{id} = $mdpItem->GetId();
        }

        if ( $req->path_info) {
            # first grab items from path_info
            my $path_info = $req->path_info;

            $path_info =~ s,.*/$id/,,;

            my $format;
            if ( $path_info =~ m,\.jpg$|\.tif$|\.png|\.pdf|\.epub$, ) {
                my $ridx = rindex($path_info, '.');
                $format = substr($path_info, $ridx + 1);
                $path_info = substr($path_info, 0, $ridx) . "/$format";
            }
            my @tmp = split(/\//, $path_info);
            shift @tmp; # id
            for my $param ( @$path_info_segments ) {
                my $value = shift @tmp;
                last unless ( defined $value );
                $$params{$param} = $value;
            }
        }

        # and then check the request params
        my @params = keys %$params;
        if ( grep(/^file$/, @params) ) { push @params, 'seq'; push @params, 'seq[]'; }
        for my $param ( @params ) {
            my @values = $req->param($param);
            next unless ( scalar @values );
            my $value;
            my $key = $param;

            print STDERR "AHOY -- $param :: @values\n";

            if ( scalar @values == 1 ) {
                $value = $values[0];
            } else {
                $value = join(',', @values);
            }
            if ( ( $param eq 'seq' || $param eq 'seq[]' ) && ( $values[0] =~ m,^\d+$, || $values[0] =~ m{^\d+,\d+} || $values[0] =~ m{^\d+\-\d+} ) ) {
                $value = "seq:" . $value;
                $key = 'file';
            }
            $$params{$key} = $value;
        }
    }

    if ( ref $args ) {
        # arguments that override the default config
        foreach my $param ( keys %$args ) {
            $$params{$param} = $$args{$param};
        }
    }
}

sub generate_output_filename {
    my ( $env, $options, $ext, $role )  = @_;

    my $mdpItem = $$env{'psgix.context'}->get_object('MdpItem');
    my $id = $mdpItem->GetId();

    my $key;
    if ( $role ) {
        # look for a cache dir specific to the role
        my $C = new Context;
        $key = "imgsrv_cache_dir_$role";
        if ( ! $C->get_object('MdpConfig')->has($key) ) {
            $key = "imgsrv_cache_dir";
        }
    }

    my $cache_dir = get_cachedir($key) . Identifier::id_to_mdp_path($id) . "_" . $mdpItem->get_modtime();
    Utils::mkdir_path( $cache_dir, $SRV::Globals::gMakeDirOutputLog ) unless ( $role && under_server() );

    my $filename = File::Pairtree::s2ppchars($id); # the id, so we can find this
    if ( scalar @$options ) {
        $filename .= "_" . Digest::MD5::md5_hex(@$options);
    }
    $filename .= ".$ext";

    return qq{$cache_dir/$filename};
}

sub run_command {
    my ( $env, $cmd ) = @_;
    my $retval = do {
        # clean up environment before launching
        local %ENV = ();
        foreach my $key ( keys %$env ) {
            next if ( ref($$env{key}) || $key =~ m,^psgi, || $key =~ m,^plack, );
            $ENV{$key} = $$env{$key};
        }
        # print STDERR "ENV = " . join(" / ", keys %ENV) . "\n";
        IPC::Run::run $cmd, '<', \undef, '2>', '/dev/null', '>', '/dev/null';
    };
    return $retval;
}

package SRV::Utils::File;

# clone of Plack::Util::IOWithPath + file removal at end
# needed to avoid Plack removing content-length from file
# downloads

use parent qw/IO::File/;
use File::Basename qw/dirname/;
use File::Path qw(remove_tree);

sub new {
    my $type = shift;
    my $filename = shift;
    my $remove_tree = shift;
    my $self = IO::File->new($filename) || die $!;
    bless $self, $type;
    ${*$self}{+__PACKAGE__} = $filename;
    ${*$self}{+__REMOVE_TREE__} = $remove_tree;
    $self;
}

sub path {
    my $self = shift;
    if (@_) {
        ${*$self}{+__PACKAGE__} = shift;
    }
    ${*$self}{+__PACKAGE__};
}

sub close {
    my $self = shift;
    $self->SUPER::close();
    # print STDERR "VANISHING: " . ${*$self}{+__PACKAGE__} . "\n";

    # if we made it this far, unlink the directory
    unlink ${*$self}{+__PACKAGE__};
    if ( ${*$self}{+__REMOVE_TREE__} ) {
        my $dirname = dirname(${*$self}{+__PACKAGE__});
        remove_tree $dirname;        
    }
}

sub DESTROY {
    my $self = shift;
    $self->close;
}

package SRV::Utils::Stream;

# clone of Plack::Util::IOWithPath + file removal at end
# needed to avoid Plack removing content-length from file
# downloads

use parent qw/IO::Handle IO::Seekable/;

use Carp;

sub new   {
    my $class = shift;

    my $fh = $class->SUPER::new();
    $fh->setpos(0);

    ${*$fh}{settings} = {@_};
    # ${*$fh}{settings}{writer} = ${*$fh}{settings}{responder}->([200, ${*$fh}{settings}{headers}]);
    #                             ${*$fh}{settings}{responder}->([200, ${*$fh}{settings}{headers}]);
    # print STDERR Data::Dumper::Dumper ${*$fh}{settings};

    $fh;
}

sub output {
    my $self = shift;
    return $self;
}

sub getpos {
    my $self = shift;
    return ${*$self}{'bogus_pos'};
}

sub setpos {
    my $self = shift;
    ${*$self}{'bogus_pos'} = shift;
}

sub seek {
    my $self = shift;
    @_ == 2 or croak 'usage: $io->seek(POS, WHENCE)';
    seek(STDOUT, $_[0], $_[1]);
}

sub tell {
    my $self = shift;
    return $self->getpos;
}

sub print {
    my $self = shift;
    for (@_) {
        $self->setpos($self->getpos + length($_));
        ${*$self}{settings}{writer}->write($_);
    }
}

sub printf {
    my $self = shift;
    $self->print(sprintf(shift, @_));
}

package SRV::Utils::Progress;

use File::Slurp;
use File::Basename qw(dirname basename);
use File::Path qw(remove_tree);
use JSON::XS qw(encode_json);

sub new {
    my $class = shift;
    my $options = { @_ };
    $$options{format} = 'js' unless ( defined $$options{format} );
    $$options{method} = "get_message_$$options{format}";
    $$options{noop} = 1 unless ( $$options{filepath} );
    $$options{type} = 'PDF' unless ( $$options{type} );
    # $$options{dirname} = dirname($$options{filename}) unless ( $$options{noop} );
    my $self = bless $options, $class;
    $self;
}

sub initialize {
    my $self = shift;
    return if ( $$self{noop} );

    my $message = $self->${ \( $$self{method} ) }(0, $$self{total_pages});
    $self->_write($message, "initialize");
}

sub filepath {
    my $self = shift;
    return $$self{filepath};
}

sub download_url {
    my $self = shift;
    return $$self{download_url};
}

sub update {
    my $self = shift;
    my $page = shift;
    return if ( $$self{noop} );
    my $message = $self->${ \( $$self{method} ) }($page, $$self{total_pages});
    $self->_write($message, $page);
}

sub finish {
    my $self = shift;
    # print STDERR "FINISHING : $$self{noop} :: $$self{filename}\n";
    return if ( $$self{noop} );
    my $message = $self->${ \( $$self{method} ) }(-1, $$self{total_pages});
    $self->_write($message, "done");
}

sub is_cancelled {
    my $self = shift;

    return 0 if ( $$self{noop} );
    return ( -f qq{$$self{filepath}/stop.$$self{format}} );
}

sub in_progress {
    my $self = shift;

    return 0 if ( $$self{noop} );
    return 0 unless ( -d $$self{filepath} );

    opendir(my $status_dh, $$self{filepath}) || die "$status_path: $!";

    my $sort = sub {
        my ( $a, $b ) = @_;
        my $ts_a = (Time::HiRes::stat "$status_path/$a" )[10];
        my $ts_b = (Time::HiRes::stat "$status_path/$b" )[10];
        return ( $ts_a <=> $ts_b );
    };

    my @filenames = sort { $sort->($b, $a) } grep(!/^\./, readdir($status_dh));
    closedir($status_dh);

    return 0 unless ( scalar @filenames );

    my $current_status_filename = $filenames[0];
    my $mod_timestamp = (Time::HiRes::stat(qq{$$self{filepath}/$current_status_filename}))[9];
    return ( Time::HiRes::time() - $mod_timestamp < 60 );
}

sub cancel {
    my $self = shift;
    write_file(qq{$$self{filepath}/stop.$$self{format}}, "STOP");
}

sub reset {
    my $self = shift;
    remove_tree qq{$$self{filepath}};
}

sub get_message_js {
    my $self = shift;
    my ( $page, $total_pages ) = @_;
    my $status = 'RUNNING';
    if ( $page < 0 ) { $status = 'DONE'; }
    my $message = { current_page => $page, total_pages => $total_pages, status => $status };
    $$message{download_url} = $$self{download_url};
    return encode_json($message);
}

sub get_message_text {
    my $self = shift;
    my ( $page, $total_pages ) = @_;

    my $download_url = '-';
    if ( $page < 0 ) {
        $page = 'EOT';
        $total_pages = 'EOT';
        $download_url = $$self{download_url};
    }

    my $message = <<MESSAGE;
$page
$total_pages
$download_url
MESSAGE

    return $message;
}

sub get_message_html {
    my $self = shift;
    my ( $page, $total_pages ) = @_;

    my $message;
    my $body;
    my $download_url;

    if ( $page < 0 ) {
        $download_url = $$self{download_url};

        $body = <<HTML;
<p><span data-value="EOT" id="current">All Done!</span></p>
<p>You can download the $$self{type} at:
    <span id="pdf_download_url">
        <a href="$download_url">$download_url</a>
    </span>
</p>
HTML
    } else {
        my $page_s = sprintf("%08d", $page);
        my $total_pages_s = sprintf("%08d", $total_pages);
        $body = <<HTML;
<p>Building: <span data-value="$page" id="current">$page_s</span> / <span data-value="$total_pages" id="total_pages">$total_pages_s</span></p>
HTML
    }

    $message = <<HTML;
<html>
    <head><title>Building: $page / $total_pages</title></head>
    <body>
        $body
    </body>
</html>
HTML

    return $message;

}

sub _write {
    my $self = shift;
    my $message = shift;
    my $filename = shift;

    my $ext = $$self{format}; # eq 'html' ? "html" : 'txt';

    if ( ! -d $$self{filepath} ) {
        Utils::mkdir_path( $$self{filepath}, $SRV::Globals::gMakeDirOutputLog );
    }

    write_file(qq{$$self{filepath}/$filename.$ext}, $message);
}

1;
