#!/usr/bin/perl
use 5.36.0;
use warnings FATAL => 'all';
use feature qw(signatures);
no warnings "experimental::signatures";
use autodie qw(:all);

use JSON;
use Time::Piece;

sub get_age($text) {
  $text =~ s/\s+\w+$//;
  my $time = Time::Piece->strptime($text, '%Y-%m-%d %H:%M:%S %z');  
  my $then = $time->epoch;
  my $now = time();
  return $now - $then;
}

my @images = `docker image ls --format '{{json .}}'`;
for my $line (@images) {
  my $image = decode_json($line);
  if ($image->{Repository} eq "sandbox") {
    my $name = "sandbox:" . $image->{Tag};
    my $cre = $image->{CreatedAt};
    my $age = get_age($cre);
    say("$name (created $cre; $age s old)");
    if ($age > 600) {
      say("Removing"); 
      system("docker image rm '$name'");
    }
  }
}

system("docker image prune -f");
system("docker builder prune -f");
