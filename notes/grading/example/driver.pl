#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

sub run($cmd) {
    system(qq{su - student -c '$cmd'});
}

sub untar($path) {
    run(qq{unpack.pl "$path"});
}

my $COOKIE = $ENV{'COOKIE'} || "=> COOKIE-COOKIE-COOKIE <=";
$ENV{'COOKIE'} = "~redacted~";

system("cp /var/tmp/unpack.pl /usr/local/bin/unpack.pl");
system("chmod a+x /usr/local/bin/unpack.pl");

untar("/var/tmp/sub.tar.gz");
run(qq{[[ -e Makefile ]] && make});

untar("/var/tmp/grading.tar.gz");
say "\n$COOKIE";
run(qq{perl test.pl});
say "\n$COOKIE";
