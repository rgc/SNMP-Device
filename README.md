SNMP-Device
===========

SNMP::Device - A perl module for gathering information from a variety of network gear using SNMP

Initially written in 2006, maintained until 2010

It will auto-detect device types based on ifDescr and use plugins located in the Device directory
to pull the correct OIDs for the information needed.

See the util directory for useful scripts for polling device information.

INSTALLATION

To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install

USAGE

	use SNMP::Device;
	use strict;

	my $ip   = shift;
	my $comm = shift;

	print "$ip\n";

	# create new Device Snapshot object from SNMP
	my $dev = new SNMP::Device (
                                        'hostname'       => $ip,
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


COPYRIGHT AND LICENCE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

