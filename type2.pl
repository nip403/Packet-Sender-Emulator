#! /usr/bin/perl

use strict;
use warnings;

use Packet;

die "Enter: Calling_Station_Id, 3GPP_IMSI, 3GPP_IMEISV" unless scalar @ARGV == 3;
my ($Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV) = @ARGV;

my $t0 = time(); # time since epoch to use as an "anchor"
my $interval = 60;

sub type2 {
    my $start = new Packet("Start", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV);
    $start->send();

    my $old_tx = 0;
    my $old_rx = 0;

    while (1) {
        sleep($interval);
        my $alive = new Packet("Alive", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV, 5000+$old_tx, 1000, 1000+$old_rx, 200);
        $alive->send();
            
        $old_tx = $alive->{"Input-Octets"};
        $old_rx = $alive->{"Output-Octets"};
    }
}

unless (caller) {
    type2();
}