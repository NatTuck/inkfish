#!/usr/bin/perl
use 5.16.0;
use warnings FATAL => 'all';
use autodie qw(:all);

my $inpath = shift or die;
my $count  = shift or die;
$count = 0 + $count;

my %trips = ();

open my $inf, "<", $inpath;
while (my $line = <$inf>) {
    chomp $line;
    my $nn = length($line);
    for (my $ii = 0; $ii <= ($nn - 3); ++$ii) {
        my $trip = substr($line, $ii, 3);
        my $prev = $trips{$trip} || 0;
        $trips{$trip} = $prev + 1;
    }
}
close $inf;

say "Trips of count $count:";

for my $trip (keys %trips) {
    my $num = $trips{$trip};
    if ($num == $count) {
        say $trip;
    }
}
