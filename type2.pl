use strict;
use warnings;

use Packet;

my ($Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV) = splice @ARGV, 0, 3;

my $interval = 60;
my $id = Packet::get_session_id();

sub type2 {
    my $start = new Packet("Start", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV, $id);
    $start->send(1, @ARGV);

    my $old_tx = 0;
    my $old_rx = 0;
    my $old_duration = 0;

    while (1) {
        sleep($interval);
        my $alive = new Packet("Alive", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV, 
                    $id, $old_duration+$interval, 
                    5000+$old_tx, 1000, 1000+$old_rx, 200);
        $alive->send(1, @ARGV);
            
        $old_tx = $alive->{"Input-Octets"};
        $old_rx = $alive->{"Output-Octets"};
        $old_duration = $alive->{"Session-Time"};
    }
}

unless (caller) {
    type2();
}