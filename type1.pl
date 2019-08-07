#! /usr/bin/perl

use strict;
use warnings;

use Packet;

die "Enter: Calling_Station_Id, 3GPP_IMSI, 3GPP_IMEISV" unless scalar @ARGV == 3;
my ($Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV) = @ARGV;

my $duration = 10;
my $interval = 300;

sub type1 {
    while (1) {
        my $start = new Packet("Start", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV);
        my $stop = new Packet("Stop", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV);
            
        $start->send();
        sleep($duration);
        $stop->send();

        sleep($interval-$duration);
    }
}

unless (caller) {
    type1();
}