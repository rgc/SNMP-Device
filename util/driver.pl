#!/usr/bin/perl -w

use SNMP::Device;

use strict;

my $ip   = shift;
my $comm = shift;

print "$ip\n";

# create new Device Snapshot object from SNMP
my $dev = new SNMP::Device (
					'hostname'	 => $ip,
					'snmp_community' => $comm,
			      	    );

if(!$dev->err) {

print "Found the following units:\n";

my $if_info = $dev->if_info();

foreach my $if (keys %{$if_info}) {

	print "$if - " . $if_info->{$if}->{'vlan_ids'} . "\n";

}
print "\n\n";

# backup config to tftp server
print $dev->log . "\n" if($dev->log);

} else {
	print $dev->err . "\n";
}

exit;
