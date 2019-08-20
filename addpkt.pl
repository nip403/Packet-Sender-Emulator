use strict;
use warnings;

use Packet;

my $mode = shift @ARGV || 0;
my $packet;

if ($mode eq "1") { # append new flags
    $packet = new Packet(splice @ARGV, 0, 4);
    $packet->send(1, @ARGV);
} 
elsif ($mode eq "0") { # override presets
    $packet = new Packet();
    $packet->send(0, @ARGV);
} 
else {
    die;
}