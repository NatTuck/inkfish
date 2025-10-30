#!/usr/bin/perl
use 5.36.0;

use JSON;

open(my $ls, "-|", "docker image ls --format '{{json .}}'");
while (<$ls>) {
  my $info = decode_json($_);
  if ($info->{Repository} eq "sandbox") {
    my $name = $info->{Repository} . ":" . $info->{Tag};
    print("Removing $name...\n");
    system(qq{docker image rm '$name'});
  }
}
