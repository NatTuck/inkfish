#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

use File::Temp qw(tempdir);

my $SCR = $ENV{'SCR'} or die "Need $ENV{'SCR'}";
my $SUB = $ENV{'SUB'} or die "Need $ENV{'SUB'}";
my $GRA = $ENV{'GRA'} or die "Need $ENV{'SUB'}";

sub tar_up($tarball, $path) {
    system(qq{(cd "$path" && tar czf "$tarball" .)});
}

sub create($image) {
    my $opts = qq{--label "autobot=1" --cpus 1 --rm};
    my $id = qx{docker create $opts "$image" perl /var/tmp/driver.pl};
    chomp $id;
    say "Created container: $image => $id";
    return $id;
}

sub copy($id, $file, $dest) {
    say "Copying in $file...";
    system(qq{docker cp "$file" $id:"$dest"});
}

sub start($id) {
    say "Starting container...";
    system(qq{docker start -a $id});
}

my $temp = tempdir( CLEANUP => 1 );
tar_up("$temp/sub.tar.gz", $SUB);
tar_up("$temp/gra.tar.gz", $GRA);

my $id = create("inkfish:latest");
copy($id, "$SCR/unpack.pl", "/var/tmp/unpack.pl");
copy($id, "$SCR/simple-driver.pl", "/var/tmp/driver.pl");
copy($id, "$temp/sub.tar.gz", "/var/tmp/sub.tar.gz");
copy($id, "$temp/gra.tar.gz", "/var/tmp/gra.tar.gz");
start($id);

