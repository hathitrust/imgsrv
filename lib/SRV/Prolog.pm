package SRV::Prolog;

use strict;
use parent qw(Plack::Middleware);

use Plack::Util;
use Plack::Util::Accessor qw( app_name );

use Debug::DUtils;

use CGI::PSGI;
use Time::HiRes qw(time);

{
    package Auth::Auth::PSGI;

    use base qw(Auth::Auth);

    use constant COSIGN => 'cosign';
    use constant SHIBBOLETH => 'shibboleth';
    use constant FRIEND => 'friend';

    sub do_redirect {
        my $self = shift;
        my ( $C, $redirect_to ) = @_;
        my $cgi = $C->get_object('CGI');
        $cgi->env->{'psgix.auth.redirect_url'} = $redirect_to;
    }
}


use App;
use Access::Rights;
use Session;
# use Auth::Auth;
use MdpConfig;
use Auth::Logging;

use MdpItem;

use Operation::Status;
use Identifier;

use Scalar::Util;
use Try::Tiny;

use Metrics;
use Utils;

# Return codes from ValidityChecks()
use constant ST_EMPTY            => 0;
use constant ST_SEQ_NOT_SUPPLIED => 1;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self;
}

sub call {
    my($self, $env) = @_;

    # skip the setup if we already have a context
    $self->setup_context($env) unless ( Scalar::Util::blessed($$env{'psgix.context'}) );
    if ( defined $$env{'psgix.auth.redirect_url'} ) {
        # should return the redirect
        $self->cleanup_context();
        return [ 302, [ "Location" => $$env{'psgix.auth.redirect_url'} ], [] ];
    }

    my $mdpItem = $$env{'psgix.context'}->get_object('MdpItem');
    if ( $$env{'psgix.context'}->get_object('Access::Rights')->suppressed($$env{'psgix.context'}, $mdpItem->GetId() ) ) {
        $self->cleanup_context();
        return [ 404, [], [] ];
    }

    my $res = try {
      $self->app->($env);
    } catch {
      # always dispose of the context!
      $self->cleanup_context($env);
      die $_;
    };

    $self->response_cb($res, sub { $self->finalize($env, $_[0]) });

}

sub cleanup_context {
    my ( $self, $env ) = @_;
    my $C = delete $$env{'psgix.context'};
    if ( Scalar::Util::blessed($C) ) {
        $C->dispose;
    }
}

sub setup_context {
    my ( $self, $env ) = @_;

    my $start = time();
    my $C = new Context;
    my $req = Plack::Request->new($env);

    my $app = new App($C, $self->app_name);
    $C->set_object('App', $app);

    # we already have the config
    my $config = $$env{'psgix.config'};

    $C->set_object('MdpConfig', $config);

    # Database connection -- order matters
    my $db = new Database('ht_web');
    $C->set_object('Database', $db);

    my $cgi = CGI::PSGI->new($env);
    $C->set_object('CGI', $cgi);

    ## CANNOT TURN OFF SESSIONS FOR COMMAND LINE
    ## scripts need the user's identity
    my $previous_sid = $cgi->cookie($config->get('cookie_name'));
    my $ses = Session::start_session($C, 0);
    $C->set_object('Session', $ses);
    $$ses{is_new} = ! ( defined $previous_sid && $previous_sid eq $ses->get_session_id ); 

    # copy the debug environment to the plack environment
    $$env{DEBUG} = $ENV{DEBUG};

    # unless ( $ENV{PSGI_COMMAND} ) {
        # Session -- order matters
        # my $ses = Session::start_session($C, 0);
        # $C->set_object('Session', $ses);
    # }

    # Auth
    my $auth = new Auth::Auth::PSGI($C);
    $C->set_object('Auth', $auth);

    # what's my $id? MMMM and should this be stored?
    my $id = $self->get_id($env);
    $id = Identifier::validate_mbooks_id($id);
    silent_ASSERT($id, qq{Invalid document id provided.});

    # Find where this item's pages and METS manifest are located
    my $itemFileSystemLocation =
        Identifier::get_item_location($id);

    silent_ASSERT( -d $itemFileSystemLocation, qq{Invalid document id provided.});

    # Determine access rights and store them on the MdpItem object
    my $ar = new Access::Rights($C, $id);
    $C->set_object('Access::Rights', $ar);
    $$env{'psgix.restricted'} = $ar->assert_final_access_status($C, $id) ne 'allow';

    # MdpItem is instantiated if it cannot be found  already cached on the session object.
    my $mdpItem =
        MdpItem->GetMdpItem($C, $id, $itemFileSystemLocation);
    $C->set_object('MdpItem', $mdpItem);

    Metrics->new->observe("imgsrv_prolog_seconds", time() - $start);

    $$env{'psgix.context'} = $C;
}

sub finalize {
    my($self, $env, $res) = @_;
    my $C = $$env{'psgix.context'};
    my $ses = $C->get_object('Session', 1);
    if ( $ses ) {
        my $cookie = $ses->get_cookie();
        Plack::Util::header_push($res->[1], 'Set-Cookie', "$cookie");

        if ( ! $$env{REMOTE_USER} ) {
            if ( my $entity_id = $ses->get_persistent('entity_id') ) {
                Plack::Util::header_push($res->[1], 'X-HathiTrust-Renew', $entity_id);
            }
        }
    }

    my $mdpItem = $C->get_object('MdpItem',1);
    my $ar = $C->get_object('Access::Rights');
    unless ( $$env{'psgix.restricted'} ) {
        # security logging
        if ( ref($mdpItem) ) {
            if ( Auth::Logging::log_incopyright_access($C, $mdpItem->GetId()) ) {
                # Auth::Logging::log_successful_access($C, $mdpItem->GetId(), 'imgsrv');
                # copy any added headers added by security logging
            }
            my $headers_ref = $C->get_object('HTTP::Headers', 1);
            if ( ref($headers_ref) ) {
                foreach my $key ( $headers_ref->header_field_names ) {
                    my $value = $headers_ref->header($key);
                    if ( defined $value ) {
                        Plack::Util::header_push($res->[1], $key, $value);
                    }
                }
            }
        }
    }

    if ( scalar @$res == 2 ) {
        # streaming; have to dispose of context _after_ returning results
        return sub {
            my ( $line ) = @_;
            if ( ! defined $line ) {
                $self->cleanup_context($env);
            }
            return $line;
        };
    }

    if ( $ar->in_copyright($C, $mdpItem->GetId()) ) {
        Auth::Logging::log_access($C, 'imgsrv') unless ( defined $$env{'psgix.imgsrv.logged'} );
    }
    $self->cleanup_context($env);
}

sub get_id {
    my ( $self, $env ) = @_;

    my $req = Plack::Request->new($env);

    # legacy; check the query_string
    my $id = $req->param('id');

    unless ( $id ) {
        # we always have path_info

        my $ARK_PATTERN = q{ark:/13960/(t|fk)\d[a-z\d][a-z\d]\d[a-z\d][a-z\d]\d[a-z\d]};
        my $ID_PATTERN = q{.+};
        my $NAMESPACE_PATTERN = q/.{2,4}/;

        my $expr = q{/((_NS_)\.((_ARK_)|(_ID_)))};
        $expr =~ s,_NS_,$NAMESPACE_PATTERN,;
        $expr =~ s,_ID_,$ID_PATTERN,;
        $expr =~ s,_ARK_,$ARK_PATTERN,;

        ($id) = $req->path_info =~ m,$expr,;

        # if there's still no @id, grab the first path element with a number
        unless ( $id ) {
            my @path = split(/\//, substr($req->path_info, 1));
            foreach ( @path ) {
                if ( $_ =~ m,\d, ) {
                    $id = $_;
                    last;
                }
            }
        }
    }

    return $id;
}

1;
