#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {
    $ENV{SDRROOT} = '/htapps/babel' unless ( exists($$ENV{SDRROOT}) );
}

use FindBin;

use lib "$ENV{SDRROOT}/mdp-lib/Utils";
use Vendors __FILE__;

use Data::Dumper;
use Date::Manip;

use Utils;

my $timestamp = shift @ARGV || UnixDate("now", "%Y-%m-%d");
my $CACHE_ROOT = join('/',
    $ENV{SDRROOT},
    # $ENV{HT_DEV} ? 'cache-full' : 'cache',
    # 'imgsrv'
);

my $log_filename = "$ENV{SDRROOT}/logs/imgsrv/build-$timestamp.log";
unless ( -f $log_filename ) {
    exit;
}

my $HOSTNAME=`hostname`; chomp $HOSTNAME;

my $IN = IO::File->new($log_filename) || die "could not open $log_filename - $!";
while ( my $line = <$IN> ) {
    my $datum = {};
    foreach my $tuple ( split(/\|/, $line) ) {
        my ( $key, $value ) = split(/=/, $tuple, 2);
        $$datum{$key} = $value;
    }

    my $was_downloaded = 0;
    if ( $$datum{filename} && ! -s "$CACHE_ROOT/$$datum{filename}" ) { $was_downloaded = 1; }

    print join("\t", $HOSTNAME, $$datum{datetime}, $$datum{id}, $$datum{size}, $was_downloaded), "\n";
}

