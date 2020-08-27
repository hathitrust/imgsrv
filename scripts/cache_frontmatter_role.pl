#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {
  $ENV{SDRROOT} = '/htapps/babel' unless defined $ENV{SDRROOT};
}

use FindBin;

use lib "$ENV{SDRROOT}/mdp-lib/Utils";
use Vendors __FILE__;

use Plack::Util;
use Process::Image;
use Plack::App::Command;
use Capture::Tiny;

my @config = (
    "id=s",
    "seq=i",
    "file=s",
    "size=s",
    "width=i",
    "height=i",
    "res=i",
    "region=s",
    "rotation=s",
    "format=s",
    "watermark=i",
    "force",
);

my $htid = $ARGV[0] || die 'No HTID specified';
my $role = $ARGV[1] || 'crms';
$ENV{'X-ENV-ROLE'} = $role;

my $app = Plack::Util::load_psgi("$FindBin::Bin/../apps/imgsrv.psgi");

foreach my $seq (1 .. 20)
{
  {
    local %ENV = %ENV;
    $ENV{PSGI_ACTION} = 'image';
    local @ARGV = ('--id', $htid, '--seq', $seq, '--size', 200);
    push @ARGV, ('--force', '1') if $ENV{FORCE};
    my ($stdout, $stderr) = Capture::Tiny::capture
    {
      Plack::App::Command->run('', \@config, $app);
    };
    print STDERR $stderr . "\n" if ( $ENV{DEBUG} );
  }
  {
    local %ENV = %ENV;
    $ENV{PSGI_ACTION} = 'thumbnail';
    local @ARGV = ('--id', $htid, '--seq', $seq, '--width', 250);
    push @ARGV, ('--force', '1') if $ENV{FORCE};
    my ($stdout, $stderr) = Capture::Tiny::capture
    {
      Plack::App::Command->run('', \@config, $app);
    };
    print STDERR $stderr . "\n" if ( $ENV{DEBUG} );
  }
}
