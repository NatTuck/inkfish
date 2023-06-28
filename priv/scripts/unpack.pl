#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

# Unpack an archive file and unnest a directory.

use File::Spec::Functions qw(rel2abs);
    

sub min ($aa, $bb) {
    return $aa < $bb ? $aa : $bb;
}

sub lcp ($aa, $bb) {
    my $nn = min(length($aa), length($bb));
    my $ii = 0;
    for (; $ii < $nn; ++$ii) {
	last unless (substr($aa, $ii, 1) eq substr($bb, $ii, 1));
    }
    return substr($aa, 0, $ii);
}

sub lcpN (@xs) {
    if (scalar(@xs) == 0) {
	return "";
    }
    my $acc = $xs[0];
    for my $xx (@xs) {
	$acc = lcp($acc, $xx);
    }
    return $acc;
}

my $archive = rel2abs(shift || die "Need an archive");

my @paths = qx{tar tf "$archive"};
chomp @paths;
@paths = grep(!/^\.\/$/, @paths);

my $prefix = lcpN(@paths);
$prefix =~ s/\/[^\/]*$//;
my $parts = scalar(split '/', $prefix);

say "Untar $archive, unnest '$prefix' ($parts).";
system(qq{tar --strip-components=$parts -xvf "$archive"});
