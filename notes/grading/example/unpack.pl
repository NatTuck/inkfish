#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

# Unpack an archive file and unnest a directory.

use File::Spec::Functions qw(rel2abs);
    
my $archive = rel2abs(shift || die "Need an archive");

my @paths = qx{tar tf "$archive"};
chomp @paths;

my $td = undef;
my $unnest = 1;
for my $path (@paths) {
    $path =~ s/^[\.\/]*//;
    next if $path =~ /\/$/;
    next unless $path =~ /\//;

    my ($top, $rest) = split('/', $path, 2);
    $td ||= $top;
    unless ($td eq $top) {
	say "No unnest ($td, $top)";
	$unnest = 0;
	last;
    }
}

if ($unnest) {
    system(qq{tar xvf "$archive" --strip-components=1});
}
else {
    system(qq{tar xvf "$archive"});
}
