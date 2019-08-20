use strict;
use warnings;

use Packet;

my ($Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV) = splice @ARGV, 0, 3;

my $duration = 30;
my $interval = 21600; # 6 hrs

sub type3 {
    while (1) {
        my $id = Packet::get_session_id();
        my $start = new Packet("Start", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV, $id);
        my $stop = new Packet("Stop", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV, $id, $duration);
                
        $start->send(1, @ARGV);
        sleep($duration);
        $stop->send(1, @ARGV);

        sleep($interval-$duration);
    }
}

unless (caller) {
    type3()
}