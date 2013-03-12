#!/usr/bin/perl

use Parallel::ForkManager;
use FileHandle;
use DBI;

use SNMP::Device;
use strict;

my $ip_param = shift;

my $fork 	= 1;
my $fork_limit  = 10;
my $tftpserver 	= 'xxx.xxx.xxx.xxx';  # fill this in

my $run_log	= 'run_log.log';
my $err_log	= 'err_log.log';

my $rlog	= new FileHandle(">$run_log");
my $elog	= new FileHandle(">$err_log");

################################################

my $rows = ();  # populate this with a 2d array of devices and community names

my $fm = new Parallel::ForkManager($fork_limit);

foreach my $row (@$rows) {
        my $ip   	= $row->[0];
        my $comm_ro 	= $row->[1];
        my $comm_rw 	= $row->[2];

	print "$ip - $comm_ro - $comm_rw\n";

      	$fm->start($ip) and next if($fork);

	# create new Device Snapshot object from SNMP
	my $dev_cfg = new SNMP::Device (
						'hostname'	 	=> $ip,
						'snmp_community_read' 	=> $comm_ro,
						'snmp_community_write' 	=> $comm_rw,
						'tftpserver'	 	=> $tftpserver,
					  );

	if(!$dev_cfg->err) {
		# backup config to tftp server
		$dev_cfg->backup();

		print $rlog $dev_cfg->log . "\n" if($dev_cfg->log);

	} else {
		print $elog $dev_cfg->err . "\n";
	}


	$fm->finish if($fork);

}

$fm->wait_all_children if($fork);

$rlog->close;
$elog->close;

exit;

