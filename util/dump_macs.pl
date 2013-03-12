#!/usr/bin/perl -w

use strict;
use SNMP::Device;
use Data::Dumper;

my $ip   = shift || die;
my $comm = shift || die;


# create new Device Snapshot object from SNMP
my $dev_cfg = new SNMP::Device (
                                'hostname'       => $ip,
                                'snmp_community' => $comm
                             );

die($dev_cfg->err) if($dev_cfg->err);

my $units = $dev_cfg->unit_info();
my $ifs   = $dev_cfg->if_info();

$dev_cfg->_loadMacTable($ifs);

print Dumper($units);
print Dumper($ifs);

exit;

foreach my $index ( sort keys %$ifs ) {
	print "$index - ";

	if($ifs->{$index}->{'macs'}) {
		foreach my $mac (sort keys %{$ifs->{$index}->{'macs'}}) {
			print "  $mac\n";
		}
	}

	print "\n";

}


exit;
