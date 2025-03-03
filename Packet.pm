#!/usr/bin/perl
package Packet;

our @types = (
    "Start",
    "Stop",
    "Alive"
);

sub new {
    my $class = shift;
    my $self = {
        type => ucfirst shift || "Start",
        "Calling-Station-Id" => shift || 886905040636, #argv
        "3GPP-IMSI" => shift || 466924200000857, #argv
        "3GPP-IMEISV" => shift || 3572210751936904, #argv

        "Session-Id" => shift || "anomaly packet",
        "Session-Time" => shift || 10, #param
        "Called-Station-Id" => "iot.internet",
    };

    die "Invalid packet type" unless $self->{type} ~~ @types;

    # certain packet types have certain 'valid' attributes
    if ($self->{type} ne "Start") {
        my $tx_base = shift || 1000000;
        my $tx_range = shift || 200000;

        my $rx_base = shift || 500000;
        my $rx_range = shift || 100000;

        $self->{"Input-Octets"} = int(rand($tx_range)) + $tx_base;
        $self->{"Output-Octets"} = int(rand($rx_range)) + $rx_base;
    }

    if ($self->{type} eq "Start") {
        delete $self->{'Session-Time'};
    }

    bless $self, $class;

    return $self
}

sub init_args {
    my $self = shift;
    my $append = shift;
    my @additional_args = @_;

    #shell args
    if (($append) || !(scalar @additional_args)) {
        my @args = (
            "/usr/local/bin/radpwtst",
            #'-s 165.22.63.200',
            "-s 127.0.0.1",
            '-secret miot',
            '-user testing',

            "-noauth",
            #"-trace 4",

            "-session_id $self->{'Session-Id'}",
            "-calling_station_id $self->{'Calling-Station-Id'}",
            "-called_station_id $self->{'Called-Station-Id'}",
            "3GPP-IMSI=$self->{'3GPP-IMSI'}",
            "3GPP-IMEISV=$self->{'3GPP-IMEISV'}",
        );

        if ($self->{type} ne "Start") {
            if ($self->{type} eq "Stop") {
                push @args, "-nostart";
            } else {
                push @args, "-alive";
                push @args, "-nostart";
                push @args, "-nostop";
            }
            
            push @args, "-session_time $self->{'Session-Time'}";

            push @args, "-Input_Octets $self->{'Input-Octets'}";
            push @args, "-Output_Octets $self->{'Output-Octets'}";

        } else {
            push @args, "-nostop";
        }

        return defined @additional_args ? (@args, @additional_args) : @args;
    } else {
        die "Provide flags or set 'append' to true" unless scalar @additional_args;
        return (("/usr/local/bin/radpwtst"), @additional_args);
    }
}

sub send {
    my $self = shift;
    my $append = shift;
    my @additional_args = @_;

    system(join " ", $self->init_args($append, @additional_args));
}

sub get_session_id {
    my $length = shift || 10;
    my @choices = (
        0..9,
        'a' .. 'z'
    );

    die if $length < 0;

    my @id;
    for (my $i = 0; $i < $length; $i++) {
        push @id, $choices[rand @choices];
    }

    return join "", @id;
}

1;