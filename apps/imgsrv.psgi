
umask 0000;
use Debug::DUtils;

use Process::Image;

use Plack::Builder;
use Plack::Builder::Conditionals::Choke;

use Plack::Request;
use Plack::Response;
use Utils;

use SRV::Image;
use SRV::Cover;
use SRV::Article::HTML;
use SRV::Volume::Metadata;
use SRV::Volume::HTML;

use Utils::Settings;
my $settings = Utils::Settings::load('imgsrv', 'imgsrv');

my $app = sub {
    my $env = shift;
    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $item_type = lc $mdpItem->GetItemType();
    Plack::Recursive::ForwardRequest->throw("/$item_type$$env{PATH_INFO}");
};

# for backward compatibility
my $metadata_app = SRV::Volume::Metadata->new->to_app;
my $html_app = SRV::Volume::HTML->new->to_app;
my $covers_app = SRV::Cover->new(restricted => 0)->to_app;

umask 0002;

sub under_server {
    return ( ! defined $ENV{PSGI_COMMAND} );
}

builder {

    if ( under_server() ) {
        enable 'URLFixer';
    }

    enable "SSO";

    enable "PopulateENV", app_name => 'imgsrv';

    enable_if { (under_server() && $ENV{HT_DEV}) } 'StackTrace';

    enable_if { (under_server() && ! $ENV{HT_DEV}) }
        "HTErrorDocument", 500 => "/mdp-web/production_500.html";

    enable_if { (under_server()) }
        "HTErrorDocument", 404 => "/mdp-web/graphics/404_image.jpg";

    enable_if { (under_server() && ! $ENV{HT_DEV}) } "HTHTTPExceptions", rethrow => 0;

    if ( under_server() ) {
        # choke policies
        enable 'Choke::Cache::Filesystem';

        enable
            match_if path(qr,^/thumbnail,),
                     'Choke::Requests',
                        %{ $$settings{choke}{'thumbnail'} },
                    ;

        enable
            match_if path(qr,^/cover,),
                     'Choke::Requests',
                        %{ $$settings{choke}{'cover'} },
                      ;

        enable
            match_if path(qr,^/metadata,),
                     'Choke::Requests',
                        %{ $$settings{choke}{'meta'} },
                     ;

        enable
            match_if path(qr,^/image,),
                     'Choke::Requests::Image',
                        %{ $$settings{choke}{'image'} },
                     ;

        enable
            match_if path(qr,/html|/ocr,),
                     'Choke::Requests',
                        %{ $$settings{choke}{'text'} },
                     ;

        enable
            match_if unchoked(),
                     'Choke::Requests',
                        %{ $$settings{choke}{'default'} },
                     ;
    }

    enable "+SRV::Prolog", app_name => 'imgsrv';
    enable "Recursive";

    mount "/" => $app;
    mount "/pdf" => sub {
        # redirect pdfs to /download/
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $uri = $req->uri;
        my $path = $uri->path;
        $path =~ s,imgsrv(2)?(/imgsrv)?/pdf,imgsrv$1/download/pdf,;
        $uri->path($path);
        my $res = $req->new_response(301);
        $res->redirect($uri);
        return $res->finalize;
    };
    mount "/volume" => builder {
        mount "/image" => SRV::Image->new->to_app;
        mount "/thumbnail" => SRV::Image->new(mode => 'thumbnail', watermark => 0)->to_app;
        mount "/html" => $html_app;
        mount "/ocr" => $html_app;
        mount "/metadata" => $metadata_app;
        mount "/meta" => $metadata_app;
        mount "/cover" => $covers_app;
    };
    mount "/article" => builder {
        mount "/image" => SRV::Image->new(watermark => 0);
        mount "/cover" => $covers_app;
        mount "/html" => SRV::Article::HTML->new;
        # mount "/file" => ...;
    }

};
