#!/usr/bin/perl
use 5.30.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

my $base = `pwd`;
chomp $base;

# Create
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

my $id = create("inkfish:latest");
copy($id, "$base/unpack.pl", "/var/tmp/unpack.pl");
copy($id, "$base/driver.pl", "/var/tmp/driver.pl");
copy($id, "$base/sub.tar.gz", "/var/tmp/sub.tar.gz");
copy($id, "$base/grading.tar.gz", "/var/tmp/grading.tar.gz");
start($id);

