#!/usr/bin/perl
use Net::SFTP::Foreign;
use File::Basename;

# Copyright(R) 2017 Acom Networks
# CHT-AIC SFTP client program
# This program will take 2 arguments from command line and transfer the file via SFTP to the remote host
# This will only work under password-less SSH configuration
# ./sftp_client.pl [transfer_ipaddress] [transfer_filename_fullpath] &

# VERSION Information
# 1.0.0: 2017-03-05 Peter Cheng (peter@acom-networks.com)
#        Initial Version

##### START: Define constants
use constant VERSION => '1.0.0';
use constant PROGRAM_NAME => 'sftp_client';
use constant LOGPATH => '/home/logs/file_transferd/';
use constant DEBUG_ON => 1;
use constant SFTP_TIMEOUT => 10;
##### END: Define constants

##### START: Get command line arguments
my $ssh_host = $ARGV[0];
my $xfer_filename = $ARGV[1];
##### END: Get command line arguments

if (! -e $xfer_filename) {
    logger("ERROR:FILENAME:$xfer_filename:Does not exist!");
    exit();
}

if (!($ssh_host =~ /^[a-z0-9.]+\@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/)) {
    logger("ERROR:SSH_HOST:$ssh_host:Not a valid SFTP resource format");
    exit();
}

##### START: Do SFTP transfer of file
my $sftp_timeout = SFTP_TIMEOUT;
my $remote_filename = basename($xfer_filename);
logger("INFO:Sending $xfer_filename to $ssh_host:$remote_filename");

my ($ssh_username,$ssh_server) = split('@', $ssh_host);
my $password = q/radius@!@#/;
logger("INFO:CONNECT:SFTP:SERVER:$ssh_server:USERNAME:$ssh_username:PASSWORD:$password:TIMEOUT:$sftp_timeout");

$sftp = Net::SFTP::Foreign->new($ssh_server, (
    user => $ssh_username,
    password => $password,
    timeout => SFTP_TIMEOUT,
));

$sftp_error = sftp_logger("CONNECT");

if ($sftp_error) {
    logger("ERROR:Could not connect to $ssh_server");
    exit();
}

logger("INFO:PUT:Putting $xfer_filename");
#$sftp->do_opendir("/home/radius"); #not sure if this works
$sftp->put($xfer_filename,$remote_filename,
           copy_perms => 0, copy_time => 0);

if (sftp_logger("PUT")) {
    logger("ERROR:PUT:FAIL:There was an error putting the file, not deleting $xfer_filename");
} else {
    logger("DEBUG:PUT:SUCCESS:DELETING $xfer_filename");
}

$sftp->disconnect;
exit();

sub logger {
    my $pidno = $$;
    my $log_line = $_[0];

    if ((!(DEBUG_ON)) && ($log_line =~ /^DEBUG/i)) {
        return;
    }

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900; $mon++; $mon = sprintf("%02d", $mon); $mday = sprintf("%02d", $mday);
    $sec = sprintf("%02d", $sec); $min = sprintf("%02d", $min); $hour = sprintf("%02d", $hour);

    my $log_datestring = $year . '-' . $mon . '-' . $mday;
    my $log_timestring = $year . $mon . $mday . ' ' . $hour . $min . $sec;

    my $logfile = LOGPATH . PROGRAM_NAME . '_' . $log_datestring . '-' . $hour . '.log';
    
    open(LOGFILE,">> $logfile");
    print LOGFILE "$log_timestring $pidno $log_line\n";
    close(LOGFILE);

    return;
}

sub sftp_logger {
    my $sftp_log_action = $_[0];
    my $sftp_status_result = $sftp->status;
    my $sftp_error_result = $sftp->error;

    logger("DEBUG:SFTP:$sftp_log_action:STATUS:$sftp_status_result:ERROR:$sftp_error_result");
    return ($sftp_error_result);
}
