package Packet;

sub new {
    my $class = shift;
    my $self = {
        type => ucfirst shift,
        "Calling-Station-Id" => shift, #argv
        "3GPP-IMSI" => shift, #argv
        "3GPP-IMEISV" => shift, #argv

        "Called-Station-Id" => "ocspilot",
    };

    if ($self->{type} eq "Stop") {
        $self->{"Input-Octets"} = int(rand(200000)) + 1000000;
        $self->{"Output-Octets"} = int(rand(100000)) + 500000;
    }

    bless $self, $class;

    return $self
}

sub init_args {
    my $self = shift;

    #shell args
    my @args = ( # 1st 3 args can be predefined
        $self->{func} || "/usr/local/bin/radpwtst",
        $self->{server} || '-s 165.22.63.200',
        $self->{secret} || '-secret miot',

        "-noauth",
        "-trace 4",

        "-calling_station_id $self->{'Calling-Station-Id'}",
        "-called_station_id $self->{'Called-Station-Id'}",
        "3GPP-IMSI=$self->{'3GPP-IMSI'}",
        "3GPP-IMEISV=$self->{'3GPP-IMEISV'}",
    );

    return @args;
}

sub send {
    my $self = shift;

    my @args = $self->init_args();

    if ($self->{type} eq "Stop") {
        push @args, "-nostart";
        push @args, "-session_time 10";
        push @args, "-Input_Octets $self->{'Input-Octets'}";
        push @args, "-Output_Octets $self->{'Output-Octets'}";
    } else {
        push @args, "-nostop";
    }

    system(join " ", @args);
}

1;