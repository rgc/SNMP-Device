package SNMP::Device::BayStack3;

use SNMP::Device;
use Net::SNMP;
use Bit::Vector;

@ISA = ('SNMP::Device');

use strict;

sub init {
        my $self        = shift;

        $self->log( ref($self) . "->init(): setting snmp version to '2'");
        $self->snmp_version('2');
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
	return 0;	
}

sub backup {
	my $self 	= shift;
	return 0;	
}

sub get_unit_info {
	my $self = shift;

	my $stack_info = {};

        my $oids = {
                        'serial'    => '.1.3.6.1.4.1.45.1.6.3.3.1.1.7.3',
                        'sys_descr' => '.1.3.6.1.4.1.45.1.6.3.3.1.1.5.3',
                        'type'      => '.1.3.6.1.4.1.45.1.6.3.3.1.1.6.3'
                   };

        foreach my $oid (keys %$oids) {
                $self->_loadTable($oids->{$oid}, $oid, $stack_info);
        }
	
	$self->_loadSwFw($stack_info); 

	return $stack_info;

}

sub get_if_info {
	my $self = shift;

	my $port_info = {};

        my $oids = {
                        'port'            => '.1.3.6.1.4.1.45.1.6.5.3.12.1.2.1',
                        'if_descr'        => '.1.3.6.1.2.1.2.2.1.2',

                        'if_status'       => '.1.3.6.1.2.1.2.2.1.8',
                        'if_ad_status'    => '.1.3.6.1.2.1.2.2.1.7',

                        # 2 disabled, 1 enabled
                        #'autoneg'         => '.1.3.6.1.4.1.2272.1.4.10.1.1.11',
                   };

        foreach my $oid (keys %$oids) {
                $self->_loadTable($oids->{$oid}, $oid, $port_info);
        }

	# get unit number		
	foreach my $num(sort keys %{$port_info}) {
		$port_info->{$num}{'unit'} = 1;

		my $mod = '';	
		$mod 	= $port_info->{$num}{'if_descr'} if($port_info->{$num}{'if_descr'});

		if($mod =~ /module\s+(\d+)/) {
			$port_info->{$num}{'unit'} = $1;
		}
		if($mod =~ /Unit\s+(\d+)/) {
			$port_info->{$num}{'unit'} = $1;
		}
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
                $self->err("couldn't get table for OID: $base_oid");
                return 0;
        }

	foreach my $k (keys %$table) {
        	$k =~ /(\d+)(\.0)*$/;
        	my $id = sprintf('%04d', $1);
		$info->{$id}{$desc} = $table->{$k};
	}

	return 1;
}

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
