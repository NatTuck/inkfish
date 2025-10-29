#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

my $id = $ENV{'CID'} || die "Need container id";

$SIG{ALRM} = sub {
    say "Timeout reached (5 minutes). Stopping container $id...";
    system(qq{docker stop $id});
};

alarm(300);

say "Starting container...";
system(qq{docker start -a $id});
