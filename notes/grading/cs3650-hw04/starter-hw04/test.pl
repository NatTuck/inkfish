#!/usr/bin/perl
use v5.16.0;
use warnings FATAL => 'all';
use autodie qw(:all);

use Test::Simple tests => 9;
use IO::Handle;

sub data_eq {
    my ($d1, $d2) = @_;

    my @l1 = split("\n", $d1);
    my @l2 = split("\n", $d2);
    my $n1 = scalar @l1;
    my $n2 = scalar @l2;

    if ($n1 != $n2) {
        say "# length mismatch $n1 != $n2";
        return 0;
    }

    for (my $ii = 0; $ii < $n1; ++$ii) {
        my $aa = $l1[$ii];
        my $bb = $l2[$ii];
        chomp $aa; $aa =~ s/\s+/ /g;
        chomp $bb; $bb =~ s/\s+/ /g;
        if ($aa ne $bb) {
            say "# data not equal on line $ii:";
            say "# aa = [$aa]";
            say "# bb = [$bb]";
            return 0;
        }
    }

    return 1;
}

sub length_test {
    my ($file, $expect) = @_;
    die "Missing test data: $file" unless (-e "$file");
    my $data1 = qx{timeout -k 10 10 ./length-sort "$file"};
    die "Missing test data: $expect" unless (-e "$expect");
    my $data2 = qx{cat "$expect"};
    ok(data_eq($data1, $data2), "length-sort '$file' matches '$expect'");
}

length_test("data/words1.txt", "data/ls0.txt");
length_test("data/words10.txt", "data/ls1.txt");
length_test("data/words.txt", "data/ls2.txt");

sub trips_test {
    my ($file, $count, $expect) = @_;
    my $data1 = qx{timeout -k 10 10 ./top-triples "$file" $count | sort -r};
    my $data2 = qx{cat "$expect" | sort -r};
    ok(data_eq($data1, $data2), "top-triples '$file' matches '$expect'");
}

trips_test("data/words1.txt", 3, "data/tt0.txt");
trips_test("data/words10.txt", 3, "data/tt1.txt");
trips_test("data/words.txt", 12, "data/tt2.txt");

sub check_errors {
    my ($errs) = @_;
    if ($errs ne "") {
        $errs =~ s/^/# /mg;
        warn $errs;
        return 0;
    }
}

sub clang_check {
    my $errs = `clang-check -analyze *.c --`;
    chomp $errs;
    check_errors($errs);
    return $errs eq "";
}

ok(clang_check(), "clang check");

sub valgrind {
    my ($cmd) = @_;
    my $vg = "valgrind -q --leak-check=full --log-file=valgrind.out";
    system(qq{timeout -k 10 10 $vg $cmd > /dev/null || true});
    my $errs = `cat -n valgrind.out`;
    check_errors($errs);
    return $errs eq "";
}

ok(valgrind(qq{./length-sort data/words10.txt}), "valgrind length-sort");
ok(valgrind(qq{./top-triples data/words.txt 37}), "valgrind top-triples");
