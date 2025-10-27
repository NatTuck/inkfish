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

my $COOKIE = $ENV{'COOKIE'} || "== COOKIE-COOKIE-COOKIE ==";
$ENV{'COOKIE'} = "~redacted~";

say("\nUnpack grading archive:");
untar("/var/tmp/gra.tar.gz");

say("\nUnpack submission:");
untar("/var/tmp/sub.tar.gz");

chdir("/home/student");

#if (-f "Makefile") {
#    say("\nFound Makefile, build:\n");
#    run(qq{make});
#}

say("\nUnpack grading archive again:");
untar("/var/tmp/gra.tar.gz");

#say "\n\n== After unpack ==\n";
#run(qq{echo -n "wd = " && pwd && ls -F});

say("\nRun test script:");
say("\n$COOKIE");

if (-f "./test.pl") {
   run(qq{perl test.pl || echo "# test.pl failed"});
}
elsif (-f "./test.py") {
    if (`cat test.py` =~ /unittest/) {
        run(qq{/usr/bin/python -m tap test.py || echo "# test.py failed"});
    }
    else {
        run(qq{/usr/bin/python test.py || echo "# test.py failed"});
    }
}
elsif (-f "./pom.xml") {
    run(qq{mvn test || echo "# mvn test failed"});
}
else {
    say("# no tests found");
}
say "\n$COOKIE\n";

say "Grading script complete."
