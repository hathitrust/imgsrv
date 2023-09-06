#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;

use HTTP::Request::Common qw(GET);
use JSON::XS;
use Plack::Test;
use Test::More;


subtest "imgsrv.psgi" => sub {
  my $app = do "$FindBin::Bin/../apps/imgsrv.psgi";
  my $test = Plack::Test->create($app);
  subtest "imgsrv/cover" => sub {
    my $res = $test->request(GET "/image?id=test.pd_open"); # HTTP::Response
    is $res->code, 200;
    is $res->message, 'OK';
    is $res->header('Content-Type'), 'image/jpeg';
  };

  subtest "imgsrv/html" => sub {
    my $res = $test->request(GET "/html?id=test.pd_open&seq=1");
    is $res->code, 200;
    is $res->message, 'OK';
    is $res->header('Content-Type'), 'text/html;charset=utf-8';
  };

  subtest "imgsrv/image" => sub {
    my $res = $test->request(GET "/image?id=test.pd_open&seq=1");
    is $res->code, 200;
    is $res->message, 'OK';
    is $res->header('Content-Type'), 'image/jpeg';
  };

  subtest "imgsrv/info" => sub {
    my $res = $test->request(GET "/info?id=test.pd_open&seq=1");
    is $res->code, 200;
    is $res->message, 'OK';
    is $res->header('Content-Type'), 'text/html';
  };

  subtest "imgsrv/metadata" => sub {
    my $res = $test->request(GET "/metadata?id=test.pd_open");
    is $res->code, 200;
    is $res->message, 'OK';
    is $res->header('Content-Type'), 'application/javascript;charset=utf-8';
    my $data = JSON::XS->new->utf8->decode($res->content);
    # Can check expected content of JSON structure
    isa_ok $data->{items}, 'ARRAY';
  };

  subtest "imgsrv/ocr" => sub {
    my $res = $test->request(GET "/ocr?id=test.pd_open&seq=1");
    is $res->code, 200;
    is $res->message, 'OK';
    is $res->header('Content-Type'), 'text/html;charset=utf-8';
  };

  subtest "imgsrv/pdf" => sub {
    my $res = $test->request(GET "/pdf?id=test.pd_open&seq=1");
    # Redirects to download app
    is $res->code, 302;
    is $res->message, 'Found';
    my $redirect = $res->header('Location');
  };
};

TODO: {
  todo_skip "As a CGI script, download.psgi dynamically loads its controllers, " .
    "and this mechanism conflicts with the from_psgi approach that Plack::Test uses under the hood.", 1;
  # Silence uninitialized complaint in lib/SRV/Volume/Base.pm
  $ENV{SERVER_NAME} = 'localhost';
  $ENV{SERVER_PORT} = 0;

  subtest "download.psgi" => sub {
    my $app = do "$FindBin::Bin/../apps/download.psgi";
    my $test = Plack::Test->create($app);
    subtest "volume/pdf" => sub {
      my $res = $test->request(GET "/pdf?id=test.pd_open");
      is $res->message, 'OK';
    };
  };
}

done_testing();

