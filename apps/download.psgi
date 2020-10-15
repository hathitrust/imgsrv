
umask 0000;
use Debug::DUtils;

use Plack::Builder;
use Plack::Builder::Conditionals::Choke;

use Plack::Request;
use Plack::Util;
use Utils;

use Utils::Settings;
my $settings = Utils::Settings::load('imgsrv', 'download');

my $app = sub {
    my $env = shift;
    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $item_type = lc $mdpItem->GetItemType();
    unless ( $$env{PATH_INFO} ) { $$env{PATH_INFO} = '/pdf'; }
    Plack::Recursive::ForwardRequest->throw("/$item_type$$env{PATH_INFO}");
};

# lazy load classes, since this app only executes one per request
my $loader = sub {
    my $cls = shift;
    return sub {
        my $env = shift;
        my $class = Plack::Util::load_class($cls);
        return $class->new->call($env);
    }
};

sub under_server {
    return ( ! defined $ENV{PSGI_COMMAND} );
}

builder {

    if ( under_server() ) {
        enable 'URLFixer';
    }

    enable "PopulateENV", app_name => 'imgsrv';

    enable_if { (under_server() && $ENV{HT_DEV}) } 'StackTrace';

    enable_if { (under_server() && ! $ENV{HT_DEV}) }
        "HTErrorDocument", 500 => "/mdp-web/production_error.html";

    enable_if { (under_server() && ! $ENV{HT_DEV}) } "HTTPExceptions", rethrow => 0;

    if ( under_server() ) {

        enable 'Choke::Cache::Filesystem';

        enable
            match_if param('marker'),
                'Choke::Null'
                ;

        enable
            match_if param('seq', qr/^\d+$/, 1),
                     'Choke::Requests',
                         %{ $$settings{choke}{'page'} }
                     ;

        enable
            match_if unchoked(),
                'Choke::Requests', 
                    %{ $$settings{choke}{'default'} }
                ;


    }

    enable "+SRV::Prolog", app_name => 'imgsrv';
    enable "Recursive";

    mount "/" => $app;
    mount "/volume" => builder {
        mount "/pdf" => $loader->('SRV::Volume::PDF');
        mount "/epub" => $loader->('SRV::Volume::EPUB');
        mount "/text" => $loader->('SRV::Volume::Text::Bundle') if ( $ENV{HT_DEV} );
    };
    mount "/article" => builder {
        mount "/pdf" => $loader->('SRV::Article::PDF');
        mount "/epub" => $loader->('SRV::Article::EPUB');
    }

};