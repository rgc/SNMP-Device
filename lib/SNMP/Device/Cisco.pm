package SNMP::Device::Cisco;

use SNMP::Device;
use Net::SNMP;
use Bit::Vector;

@ISA = ('SNMP::Device');

use strict;

sub init {
	my $self	= shift;

	$self->log( ref($self) . "->init(): setting snmp version to '2'");
	$self->snmp_version('snmpv2c');
	$self->{_snmp} = undef;
	$self->log( ref($self) . "->init(): resetting snmp session");
	$self->snmp;

	return 1;
}

sub port_status {
        my $self = shift;
        my $if   = shift || return 0;
        my $dir  = shift || return 0;

        $self->snmp->{_security}->{_community} = $self->snmp_community_write;

        my $oid_val = ($dir eq 'down')?2:1;

        my $oid = ".1.3.6.1.2.1.2.2.1.7.$if";
        return $self->snmp->set_request(-varbindlist => [$oid, INTEGER, $oid_val]);
}

sub restore {
	my $self 	= shift;
	my $direction 	= "3";	# get cfg from tftp server
}

sub backup {
	my $self 	= shift;
}

sub get_unit_info {
	my $self = shift;

	my $stack_info = {};

	my $oids = {
        		'serial'        => '.1.3.6.1.4.1.9.5.1.3.1.1.26',
			'type'		=> '.1.3.6.1.4.1.9.5.1.3.1.1.17',
			'software'	=> '.1.3.6.1.4.1.9.5.1.3.1.1.19',
		   };
	
        foreach my $oid (keys %$oids) {
                $stack_info = $self->_loadTable($oids->{$oid}, $oid, $stack_info);
        }
	
	#$self->_loadSwFw($stack_info); 

	return $stack_info;

}

sub get_if_info {
	my $self = shift;

	my $port_info = {};

	my $oids = {
        		'if_descr'        => '.1.3.6.1.2.1.2.2.1.2',
        		'if_alias'        => '.1.3.6.1.2.1.31.1.1.1.18',

        		'if_status'       => '.1.3.6.1.2.1.2.2.1.8',
        		'if_ad_status'    => '.1.3.6.1.2.1.2.2.1.7',
			'vlan_ids'	  => '.1.3.6.1.4.1.9.9.68.1.2.2.1.2',
			# duplex - 3 full, 2 half, 1 unknown
			'duplex'          => '.1.3.6.1.2.1.10.7.2.1.19',
			# speed in bps e.g. 10000000,100000000,1000000000
			'speed'           => '.1.3.6.1.2.1.2.2.1.5',

			#'vlan_port_type'  => '.1.2.840.10006.300.43.1.2.1.1.24',
			#'vlan_default_id' => '.1.3.6.1.4.1.9.9.68.1.2.2.1.2',

			# 2 disabled, 1 enabled
			#'autoneg'         => '.1.3.6.1.4.1.2272.1.4.10.1.1.11',
			# 0=0, 1=10, 2=100, 3=1000
			#'speed'           => '.1.3.6.1.4.1.2272.1.4.10.1.1.14',
		   };

        foreach my $oid (keys %$oids) {
                $port_info = $self->_loadTable($oids->{$oid}, $oid, $port_info);
        }

	#$self->_loadVlanPortMembers($port_info);
	#$self->_loadMacTable($port_info);

	# get unit number		
	foreach my $num(sort keys %{$port_info}) {
		$port_info->{$num}{'unit'} = 1;

		my $mod = '';	
		$mod    = $port_info->{$num}{'if_descr'} if($port_info->{$num}{'if_descr'});

		# GigabitEthernet3/0/7
		if($mod =~ /\w+(\d+)\/\d+\/(\d+)$/) {
			$port_info->{$num}{'unit'} = $1;
			$port_info->{$num}{'port'} = $2;
		}

		# GigabitEthernet0/7
		if($mod =~ /\w+\d+\/(\d+)$/) {
			$port_info->{$num}{'unit'} = 1;
			$port_info->{$num}{'port'} = $1;
		}

		# map speed to match nortel convention...
        	my $speed_map = {
                                	"1000000000" => "3",
                                	"100000000"  => "2",
                                	"10000000"   => "1",
                                	"0"          => "0",
                                	""           => "0",
                         	};

		$port_info->{$num}{'speed'} = $speed_map->{$port_info->{$num}{'speed'}};
		

	}
	return $port_info;

}

sub _loadMacTable {
        my $self        = shift;
        my $info        = shift;

        my $base_oid = '.1.3.6.1.2.1.17.4.3.1.2';
        my $desc     = 'macs';

        my $table = $self->snmp->get_table(-baseoid => $base_oid);

        foreach my $k (keys %$table) {
		my ($m1, $m2, $m3, $m4, $m5, $m6)
			= ($k =~ /^.*?\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/); # MAC pieces, base 10.

		#OSS::PadLeft ($m1, '0', 2);

		$m1 = sprintf("%x", $m1);
		$m1 = sprintf("%02s", $m1);
       		$m2 = sprintf("%x", $m2);
		$m2 = sprintf("%02s", $m2);
       		$m3 = sprintf("%x", $m3);
		$m3 = sprintf("%02s", $m3);
       		$m4 = sprintf("%x", $m4);
		$m4 = sprintf("%02s", $m4);
       		$m5 = sprintf("%x", $m5);
		$m5 = sprintf("%02s", $m5);
       		$m6 = sprintf("%x", $m6);
		$m6 = sprintf("%02s", $m6);
		my $mac = "$m1$m2$m3$m4$m5$m6";

		my $ifIndex = $table->{$k};

		next if(!$ifIndex);

                my $id = sprintf("%04d", $ifIndex);

                if(!defined($info->{$id}{$desc}) ) {
			$info->{$id}{$desc} = {};
		}
		$info->{$id}{$desc}->{$mac} = 1;
        }

        return;
}

sub _loadTable {
	my $self	= shift;	
	my $base_oid    = shift;
	my $desc        = shift;
	my $info	= shift;

	my $table = $self->snmp->get_table(-baseoid => $base_oid);
	if (!defined($table)) {
		$table = $self->snmp->get_table(-baseoid => $base_oid);

		if (!defined($table)) {
			$self->err("couldn't get table for OID: $base_oid");
			return 0;
		}
        }

	foreach my $k (keys %$table) {
        	$k =~ /(\d+)(\.0)*$/;
        	my $id = sprintf('%04d', $1);

#		weird, version 2 does something odd here
#		print "$base_oid - $k - $id - $desc - " . $table->{$k} . "\n";

		$info->{$id}{$desc} = $table->{$k};
	}

	return $info;
}

sub _loadVlanPortMembers {
	my $self	= shift;
	my $info	= shift;

      	# enterprises.rapidCity.rcMgmt.rcVlan.rcVlanPortTable.rcVlanPortEntry.rcVlanPortVlanIds
	my $base_oid = '.1.3.6.1.4.1.2272.1.3.3.1.3';
        my $desc     = 'vlan_ids';

        # turn off session translation... that's b/c these are mal-formed HEX values being returned
        # and Net::SNMP thinks that they are ascii chars sometimes...

        $self->snmp->translate([
                              -all     => 0x0
                            ]);

        my $table = $self->snmp->get_table(-baseoid => $base_oid);

        if (!defined($table)) {
		# try one more freakin time
        	$table = $self->snmp->get_table(-baseoid => $base_oid);

		if (!defined($table)) {
			$self->err("couldn't get table for OID: $base_oid");
			return 0;
		}
        }

        foreach my $k (keys %$table) {
                $k =~ /(\d+)$/;
                my $id = sprintf("%04d", $1);

                my $hex = sprintf('0x%s', unpack('H*', $table->{$k}));
                $hex =~ s/^0x//;
                next if $hex =~ //;

                $hex =~ substr($hex,0,4);

                my @a = split(//,$hex);         # this will catch multiple vlans
                my @vlans = ();

                while($#a > 0) {
                      my $h = join('', splice(@a,0,4));
                      my $vec = Bit::Vector->new_Hex(16, $h);
                      push(@vlans, $vec->to_Dec());
                }

		$info->{$id}{$desc} = join(',', @vlans);

        }
        return 1;
} # end _loadVlanPortMembers

sub _loadSwFw {
	my $self	= shift;
	my $info	= shift;

        my $base_oid    = '.1.3.6.1.4.1.45.1.6.3.5.1.1.7';

        my $table = $self->snmp->get_table(-baseoid => $base_oid);

	if (!defined($table)) {
		$self->err("couldn't get table for OID: $base_oid");
		return 0;
	}

        foreach my $k (keys %$table) {
        	$k =~ /(\d+)(\.0\.\d)*$/;

                my $id = sprintf("%04d", $1);
		if($2 eq ".0.1") {
			$info->{$id}{'software'} = $table->{$k};
		} elsif ($2 eq ".0.2") {
			$info->{$id}{'firmware'} = $table->{$k};
		} else {

		}
        }
        return 1;

} # end _loadSwFw

1;
