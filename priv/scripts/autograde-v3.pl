#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

use File::Temp qw(tempdir);

my $id = shift or die "Need container ID.";

say("Running in docker container:");
system(qq{docker container inspect $id});

my $SCR = $ENV{'SCR'} or die "Need $ENV{'SCR'}";
my $SUB = $ENV{'SUB'} or die "Need $ENV{'SUB'}";
my $GRA = $ENV{'GRA'} or die "Need $ENV{'GRA'}";
my $COOKIE = $ENV{'COOKIE'} or die "Need $ENV{'COOKIE'}";

sub tar_up($tarball, $path) {
    say "Tar up $path";
    system(qq{(cd "$path" && tar czf "$tarball" .)});
}

sub copy($id, $file, $dest) {
    say "Copying in $file...";
    system(qq{docker cp "$file" $id:"$dest"});
}

sub start($id) {
    say "Starting container...";
    system(qq{docker start -a $id});
}

sub count_containers {
    my $nn = 0 + `docker container ls --format '{{json .}}' | wc -l`;
    return $nn;
}

sub reap {
    my $home = $ENV{'HOME'};
    if (-e "$home/reap-old-v1.pl") {
        system(qq{(perl ~/reap-old-v1.pl 2>&1) > /dev/null &});
    }
}

my $temp = tempdir( CLEANUP => 1 );
tar_up("$temp/sub.tar.gz", $SUB);
tar_up("$temp/gra.tar.gz", $GRA);

copy($id, "$SCR/unpack.pl", "/var/tmp/unpack.pl");
copy($id, "$SCR/simple-driver.pl", "/var/tmp/driver.pl");
copy($id, "$temp/sub.tar.gz", "/var/tmp/sub.tar.gz");
copy($id, "$temp/gra.tar.gz", "/var/tmp/gra.tar.gz");

while (my $count = count_containers() > 2) {
    say("Too many containers: $count\n");
    say("Waiting 10 seconds...\n");
    reap();
    sleep(10);
}

start($id);

reap();
