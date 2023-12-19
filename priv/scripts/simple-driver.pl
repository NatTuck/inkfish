#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

alarm(300);

sub run($cmd) {
    #say "Running: $cmd";
    system(qq{su - student -c '$cmd'});
}

sub untar($path) {
    run(qq{unpack.pl "$path"});
}

my $COOKIE = $ENV{'COOKIE'} || "=> COOKIE-COOKIE-COOKIE <=";
$ENV{'COOKIE'} = "~redacted~";

system("cp /var/tmp/unpack.pl /usr/local/bin/unpack.pl");
system("chmod a+x /usr/local/bin/unpack.pl");

say("\nUnpack grading archive:");
untar("/var/tmp/gra.tar.gz");

say("\nUnpack submission:");
untar("/var/tmp/sub.tar.gz");

say("\nAttempt build:");
run(qq{[[ -e Makefile ]] && make || echo No Makefile});

say("\nUnpack grading archive again:");
untar("/var/tmp/gra.tar.gz");

#say "\n\n== After unpack ==\n";
#run(qq{echo -n "wd = " && pwd && ls -F});

say("\nRun test script:");
say "\n$COOKIE";
run(qq{perl test.pl || echo "# test script failed"});
say "\n$COOKIE\n";

say "Grading script complete."
