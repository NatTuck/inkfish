#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

my $id = $ENV{'CID'} || die "Need container id";
my $seconds = $ENV{'SECONDS'} || 300;

use JSON;

$SIG{ALRM} = sub {
    say "Timeout reached ($seconds seconds). Stopping container $id...";
    system(qq{docker stop $id});
};

alarm($seconds);

say "Starting container...";
system(qq{docker start -a $id});
