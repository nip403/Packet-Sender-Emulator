#!/usr/bin/perl -w
use strict;
use Sys::Hostname;
use Net::Ping;

# Copyright(R) 2017 Acom Networks
# CHT-AIC Auto SFTP program daemon
# This wrapper program will check for files created by RADIUS server and call the transfer client to send that file
# The calling SFTP program will be executed in the background without return
# ./sftp_client.pl [transfer_ipaddress] [transfer_filename_fullpath] &

# VERSION Information
# 1.0.0: 2017-03-05 Peter Cheng (peter@acom-networks.com)
#        Initial Version
# 1.0.1: 2017-03-09 Peter Cheng (peter@acom-networks.com)
#        Added support for 'blank CSV' file generation
# 1.0.2: 2017-07-16 Peter Cheng (peter@acom-networks.com)
#        Added support to ping neighbor for health check

##### START: Define constants
use constant VERSION => '1.0.2';
use constant PROGRAM_NAME => 'file_transferd';
use constant INIFILE => '/root/acom/file_transferd.ini';
use constant LOGPATH => '/home/logs/file_transferd/';
use constant SFTP_PROGRAM => '/root/acom/sftp_client.pl';
use constant SLEEP_TIME => 10;
use constant OUTGOING_DIR => '/home/outgoing/';
use constant DEBUG_ON => 1;
##### END: Define constants

##### START: Infinite Loop
# We do this here to read the INI file each run, this way we can avoid
# restarting the service when the INI file changes
while (1) {
    ##### START: Define and read INI file
    my $configfile = INIFILE;
    my %cfg = ();

    logger("START:Reading config file $configfile");
    if (-e $configfile) {
        %cfg = ();
        %cfg = &fill_ini($configfile);
    } else {
        logger("ERROR:CONFIGFILE:$configfile not found");
        print "Error: Config file $configfile not found on system\n";
        print "Usage: " . PROGRAM_NAME . "\n";
        print "Copyright(C) 2017 Acom Networks\n";
        print "Version: " . VERSION . "\n";
        print "\n";
        exit(1);
    }
    ##### END: Define and read INI file

    ##### START: Check existance of SFTP_PROGRAM
    if (! -e SFTP_PROGRAM) {
        logger("ERROR:SFTP_PROGRAM:" . SFTP_PROGRAM . " not found");
        print "Error: SFTP Program " . SFTP_PROGRAM . " not found on system\n";
        print "Usage: " . PROGRAM_NAME . "\n";
        print "Copyright(C) 2017 Acom Networks\n";
        print "Version: " . VERSION . "\n";
        print "\n";
        exit(1);
    }
    ##### END: Check existance of SFTP_PROGRAM

    ##### Bring in [system] variables
    my $blank_generation = $cfg{'system'}->{'blank_generation'};

    my @hosts = map {
        $cfg{'system'}->{"P$_"};
    } (0..9);

    my @dests = map {
        $cfg{'system'}->{"DEST$_"};
    } (0..9);

    my @to_delete;

    logger("INFO:HEALTH_CHECK:OFF:DEFAULT:TRANSFER");
    for (my $i = 0; $i < 10; $i++) {
        foreach my $host (split ", ", $hosts[$i]) {
            @to_delete = (@to_delete, check_and_transfer("P$i", $host, $blank_generation, $dests[$i]));
        }
    }

    logger("DEBUG:SLEEPING for ". SLEEP_TIME . " seconds");
    sleep SLEEP_TIME;
    
    foreach (@to_delete) {
        unlink $_;
    }
}
exit(1);

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

sub fill_ini (\$) {
    my ($array_ref) = @_;
    my $configfile = $array_ref;

    my %hash_ref;

    # print "SUB:CONFIGFILE:$configfile\n";
    open(CONFIGFILE,"< $configfile");
    my $main_section = 'main';
    my ($line,$copy_line);

    while ($line=<CONFIGFILE>) {
        chomp($line);
        $line =~ s/\n//g;
        $line =~ s/\r//g;
        $copy_line = $line;

        # Skip starting hash
        unless ($line =~ /^#/) {
            if ($line =~ /\[(.*)\]/) {
		        # print "SUB:FOUNDSECTION:$1\n";
		        $main_section = $1;
		    }
            if ($line eq "") {
                # print "SUB:BLANKLINE\n";
		    }
            if ($line =~ /(.*)=(.*)/) {
                my ($key,$value) = split /=/, $copy_line, 2;
                # my ($key,$value) = split('=', $copy_line);
                $key =~ s/ //g;
                $key =~ s/\t//g;
                $value =~ s/^\s+//g;
                $value =~ s/\s+$//g;
                # print "SUB:KEYPAIR:$main_section -> $key -> $value\n";
                $hash_ref{"$main_section"}->{"$key"} = $value;
            }
        }
    }
    close(CONFIGFILE);

    # $ftphost = $hash_ref{'ftp'}->{'ftphost'};
    # print "SUB:FTPHOST:$ftphost\n";

    return %hash_ref;
}

sub check_and_transfer {
    my ($p_policynum,$p_ssh_host,$p_blank_generation,$p_dest) = @_;

    logger("DEBUG:TRANSFER:POLICY:$p_policynum:SSH_HOST:$p_ssh_host:BLANK_GENERATION:$p_blank_generation:DESTHOST:$p_dest");
    my $outgoing_dir = OUTGOING_DIR . $p_policynum;# . '/';

    if (! -e $outgoing_dir) {
        logger("DEBUG:POLICY_NUM:$p_policynum:OUTGOING_DIR:$outgoing_dir:DOES NOT EXIST:No files to transfer");
        return;
    }

    my $p_hostname = hostname;

    # Define maximum file date to delete
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);# - SLEEP_TIME);
    $year += 1900; $mon++; $mon = sprintf("%02d", $mon); $mday = sprintf("%02d", $mday);
    $sec = sprintf("%02d", $sec); $min = sprintf("%02d", $min); $hour = sprintf("%02d", $hour);

    my $max_date = $year . $mon . $mday . $hour . $min . substr($sec,0,1) . '0';
    logger("INFO:POLICY_NUM:$p_policynum:OUTGOING_DIR:$outgoing_dir:Checking for files less than $max_date");

    opendir(OUTDIR, $outgoing_dir);
    my $f1_transfer_filecount = 0;
    my $f2_transfer_filecount = 0;

    my @all_files_transferred;

    while (my $outfilename = readdir(OUTDIR)) {
        if ($outfilename =~ /^\d{14}_/) {
            logger("DEBUG:POLICY_NUM:$p_policynum:Checking file $outfilename");
            my @filename_data = split("_", $outfilename);
            my $filename_datetime = $filename_data[0];

            if ($filename_datetime <= $max_date) {
                logger("INFO:POLICY_NUM:$p_policynum:DELETING:FILENAME:$outfilename:$p_ssh_host");
                my $outfilename_fullpath = OUTGOING_DIR . $p_policynum . '/' . $outfilename;
                
                if ($p_ssh_host =~ /^[a-z0-9.]+\@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) {
                    logger("DEBUG:CALLING SFTP_PROGRAM:" . SFTP_PROGRAM . ":SSH_HOST:$p_ssh_host:FILENAME:$outfilename_fullpath");
                    my $cmd_line = "perl " . SFTP_PROGRAM . " '" . $p_ssh_host . "' $outfilename_fullpath &";
                    system($cmd_line);

                    if ($outfilename =~ /_F1_Acct/) {
                        $f1_transfer_filecount++;
                    }
                    if ($outfilename =~ /_F2_Acct/) {
                        $f2_transfer_filecount++;
                    }

                    push @all_files_transferred, $outfilename_fullpath;

                } else {
                    logger("ERROR:POLICY_NUM:$p_policynum:SFTP_HOST:$p_ssh_host:NOT VALID");
                }
            } else {
                logger("DEBUG:POLICY_NUM:$p_policynum:FILENAME:$outfilename:$p_ssh_host:Too young to transfer");
            }
        }
    }
    close(OUTDIR);

    return @all_files_transferred;

    # if (!$f1_transfer_filecount) {
    #     if ($p_blank_generation) {
    #         my $blank_filename = OUTGOING_DIR . $p_policynum . '/' . $max_date . '_' . $p_policynum . '_' . $p_hostname . '_' . $p_dest . '_F1_Acct.csv';
            
    #         logger("INFO:GENERATING BLANK FILE F1 TO TRANSFER:$blank_filename");
    #         open(BLANKFILE,">> $blank_filename");
    #         close(BLANKFILE);

    #         if ($p_ssh_host =~ /^[a-z0-9.]+\@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) {
    #             logger("DEBUG:CALLING SFTP_PROGRAM:" . SFTP_PROGRAM . ":SSH_HOST:$p_ssh_host:FILENAME:$blank_filename");
    #             my $cmd_line = SFTP_PROGRAM . " '" . $p_ssh_host . "' $blank_filename &";
    #             system($cmd_line);
    #         } else {
    #             logger("ERROR:POLICY_NUM:$p_policynum:SFTP_HOST:$p_ssh_host:NOT VALID");
    #         }
    #     }
    # }
    # if (!$f2_transfer_filecount) {
    #     if ($p_blank_generation) {
    #         my $blank_filename = OUTGOING_DIR . $p_policynum . '/' . $max_date . '_' . $p_policynum . '_' . $p_hostname . '_' . $p_dest . '_F2_Acct.csv';
            
    #         logger("INFO:GENERATING BLANK FILE F2 TO TRANSFER:$blank_filename");
    #         open(BLANKFILE,">> $blank_filename");
    #         close(BLANKFILE);

    #         if ($p_ssh_host =~ /^[a-z0-9.]+\@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) {
    #             logger("DEBUG:CALLING SFTP_PROGRAM:" . SFTP_PROGRAM . ":SSH_HOST:$p_ssh_host:FILENAME:$blank_filename");
    #             my $cmd_line = SFTP_PROGRAM . " '" . $p_ssh_host . "' $blank_filename &";
    #             system($cmd_line);
    #         } else {
    #             logger("ERROR:POLICY_NUM:$p_policynum:SFTP_HOST:$p_ssh_host:NOT VALID");
    #         }
    #     }
    # }
}

sub clear_files {
    my ($p_policynum,$p_ssh_host,$p_blank_generation,$p_dest) = @_;

    logger("DEBUG:CLEAR_FILES:POLICY:$p_policynum");
    my $outgoing_dir = OUTGOING_DIR . $p_policynum . '/';

    if (! -e $outgoing_dir) {
        logger("DEBUG:POLICY_NUM:$p_policynum:OUTGOING_DIR:$outgoing_dir:DOES NOT EXIST:No files to delete");
        return;
    }

    # Define maximum file date to delete
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time - SLEEP_TIME);
    $year += 1900; $mon++; $mon = sprintf("%02d", $mon); $mday = sprintf("%02d", $mday);
    $sec = sprintf("%02d", $sec); $min = sprintf("%02d", $min); $hour = sprintf("%02d", $hour);

    my $max_date = $year . $mon . $mday . $hour . $min . substr($sec,0,1) . '0';
    logger("INFO:POLICY_NUM:$p_policynum:OUTGOING_DIR:$outgoing_dir:Checking for files less than $max_date");

    opendir(OUTDIR, $outgoing_dir);
    while (my $outfilename = readdir(OUTDIR)) {
        if ($outfilename =~ /^\d{14}_/) {
            logger("DEBUG:POLICY_NUM:$p_policynum:Checking file $outfilename");
            my @filename_data = split("_", $outfilename);
            my $filename_datetime = $filename_data[0];

            if ($filename_datetime <= $max_date) {
                logger("INFO:POLICY_NUM:$p_policynum:DELETING:FILENAME:$outfilename");
                my $outfilename_fullpath = OUTGOING_DIR . $p_policynum . '/' . $outfilename;
                unlink $outfilename_fullpath;
            } else {
                logger("DEBUG:POLICY_NUM:$p_policynum:FILENAME:$outfilename:Too young to delete");
            }
        }
    }
    close(OUTDIR);
}
