#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use ARS;

use SNMP::Device;

my $help    = '';
my $quiet   = '';
my $ip      = '';
my $if      = '';
my $unit    = '';
my $port    = '';
my $comm_r  = 'public';
my $comm_w  = 'public';
my $up      = '';
my $down    = '';
my $dir     = 'up';   # default, turn port on

GetOptions ('help' => \$help, 'quiet' => \$quiet, 'ip=s' => \$ip, 'unit=s' => \$unit, 'port=s' => \$port, 'if=s' => \$if, 'down' => \$down, 'up' => \$up);

if ($help) {
	Usage ();
	exit;
}
if(!$ip || !($up || $down) || ($up && $down) || (!$unit && !$port && !$if) || (($unit || $port) && $if) ) {
	Usage ();
	exit;
}

$dir = 'down' if($down);
$dir = 'up'   if($up);

($comm_r, $comm_w) = fetchComm();

# create new Device Snapshot object from SNMP
my $dev = new SNMP::Device (
					'hostname'	       => $ip,
					'snmp_community_read'  => $comm_r,
					'snmp_community_write' => $comm_w,
			      	    );

if(!$dev->err) {

	if(!$quiet) {
		print "\n";
		print "IP Address  : $ip\n";
		print "Read  Commmunity  : " . $dev->snmp_community_read  . "\n";
		print "Write Commmunity  : " . $dev->snmp_community_write . "\n";
		print "Device type : " . $dev->device_type() . "\n";

	}
	
	if($if) {
		print "Finding Unit and Port Info for IfIndex $if...\n";
		my $if_info = $dev->if_info();

		foreach my $key ( keys %$if_info ) {
			if($key == $if) {
				$unit = $if_info->{$key}->{'unit'};
			 	$port = $if_info->{$key}->{'port'};
			}
		}
	
	} elsif($unit && $port) {
		print "Finding IfIndex for Unit $unit and Port $port...\n";
		my $if_info = $dev->if_info();

		foreach my $key ( keys %$if_info ) {
			if( $if_info->{$key}->{'unit'}==$unit && $if_info->{$key}->{'port'}==$port ) {
				$if = int($key);
			}
		}

	} else {
		print "unhandled exception!\n";
		exit;
	}

	print "  if: $if   \n" .
	      "unit: $unit \n" .
	      "port: $port \n" ;

	exit;

	if($dev->port_status($if, $dir)) {
		print "Success!\n\n" 				if(!$quiet);
	} else {
		print "Failed!\n\n" 				if(!$quiet);
		print $dev->err . "\n" 				if($dev->err && !$quiet);
	}

} else {
	print $dev->err . "\n" if(!$quiet);
}

exit;

sub Usage {
  print "Usage: $0 [options]\n";
  print "where [options] include:\n";
  print "\t-help          => Help\n";
  print "\t-quiet         => Supress all output\n";
  print "\t-ip=\$IP        => Device IP   (required)\n";
  print "\t-if=\$IF        => IF Index    (optional, can be used in lieu of unit/port)\n";
  print "\t-unit=\$UNIT    => Unit Number (optional, must be used with port)\n";
  print "\t-port=\$PORT    => Port Number (optional, must be used with unit)\n";
  print "\t-up            => Enable Interface\n";
  print "\t-down          => Disabled Interface\n";
}

