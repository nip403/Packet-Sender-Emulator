#! /usr/bin/perl

use strict;
use warnings;

use Packet;

my $mode = shift @ARGV;
my $packet;

if ($mode eq "1") { # append new flags
    die "Not enough flags" unless scalar @ARGV >= 4;
    $packet = new Packet(splice @ARGV, 0, 4);
    $packet->send(1, @ARGV);
} 
elsif ($mode eq "0") { # override presets
    $packet = new Packet();
    $packet->send(0, @ARGV);
} 
else {
    die "1st arg: 1=Append, 0=Write";
}