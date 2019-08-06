use strict;
use warnings;

use Packet;

die "Enter: Calling_Station_Id, 3GPP_IMSI, 3GPP_IMEISV" unless scalar @ARGV == 3;
my ($Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV) = @ARGV;

my $t0 = time(); # time since epoch to use as an "anchor"
my $sleep_interval = 10; # interval between start & stop packet
my $interval = 300; # interval between checks

while (1) {
    my $tmod = (time() - $t0) % $interval; # periodic counter

    if ((0 <= $tmod) && ($tmod <= 2)) { # given a range as sometimes it weirdly skips/lags
        my $start = new Packet("Start", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV);
        my $stop = new Packet("Stop", $Calling_Station_Id, $var_3GPP_IMSI, $var_3GPP_IMEISV);
        
        $start->send();
        sleep($sleep_interval);
        $stop->send();
    }
}