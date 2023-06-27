#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

use Test::Simple tests => 1;

my $text = qx{java Hello};
chomp $text;
ok($text eq "Hello, world", "prints correct text");
