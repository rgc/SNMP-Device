package SNMP::Device::HP_AS_HUB;

use SNMP::Device;
use Net::SNMP;

@ISA = ('SNMP::Device');
use strict;

sub restore {
	return 0;
}

sub backup {
	return 0;
}

sub port_status {
        my $self = shift;
	my $if   = shift || return 0;
	my $dir  = shift || return 0;

	$self->snmp->{_security}->{_community} = $self->snmp_community_write;

	my $oid_val = ($dir eq 'down')?2:1;

	my $oid = ".1.3.6.1.2.1.22.1.3.1.1.3.1.$if";
	return $self->snmp->set_request(-varbindlist => [$oid, INTEGER, $oid_val]);
}

sub get_unit_info {
	my $self = shift;

	my $stack_info = {};
	
	my $oids = {
			'type'	  	  => '.1.3.6.1.2.1.2.2.1.2',
			'sys_descr'       => '.1.3.6.1.2.1.2.2.1.2',
		   };

        foreach my $oid (keys %$oids) {
               	$self->_loadTable($oids->{$oid}, $oid, $stack_info);
        }

	return $stack_info;

}

sub get_if_info {
	my $self = shift;

	my $port_info = {};

	my $oids = {
			'port'	  	  => '.1.3.6.1.2.1.22.1.3.1.1.2.1',
			'if_descr'  	  => '.1.3.6.1.2.1.22.1.3.1.1.2.1',
			'if_ad_status'	  => '.1.3.6.1.2.1.22.1.3.1.1.3.1',
			'if_status'	  => '.1.3.6.1.2.1.22.1.3.1.1.5.1'
		   };

        foreach my $oid (keys %$oids) {
               	$self->_loadTable($oids->{$oid}, $oid, $port_info);
        }

	return $port_info;

}

sub _loadTable {
	my $self	= shift;	
	my $base_oid    = shift;
	my $desc        = shift;
	my $info	= shift;

	my $table = $self->snmp->get_table(-baseoid => $base_oid);
	if (!defined($table)) {
		foreach my $num(sort keys %{$info}) {
			$info->{$num}{$desc} = 'N/A';
		}
		return 0;
        }

	foreach my $k (keys %$table) {
        	$k =~ /(\d+)(\.0)*$/;
        	my $id = sprintf('%04d', $1);
		$info->{$id}{$desc} = $table->{$k};
	}

	return 1;
}

1;

