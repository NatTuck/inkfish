#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

sub start($id) {
    say "Starting container...";
    system(qq{docker start -a $id});
}

my $id = $ENV{'CID'} || die "Need container id";

start($id);
