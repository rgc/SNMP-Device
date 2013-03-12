package SNMP::Device;

use Socket;
use Net::SNMP;
use Error qw(:try);
use strict;

our $VERSION = '0.01';

sub AUTOLOAD {
	no strict;
	return if($AUTOLOAD =~ /::DESTROY$/);
 	if ($AUTOLOAD=~/(\w+)$/) {
   		my $field = $1;
   		*{$field} = sub {
     				my $self = shift;
     				@_ ? $self->{"_$field"} = shift
       				   : $self->{"_$field"};
   				};
   		&$field(@_);
 	} else {
   		die("Cannot figure out field name from '$AUTOLOAD'");
 	}
}


sub new {
	my($class,%param) = @_;

    	my $self = {};
    	bless $self, ref($class) || $class;
    	$self->_initialize(%param);

	if($self->plugin) {
		$class = $self->plugin; 
		bless $self, ref($class) || $class;
    		$self->log("SNMP::Device has changed to a " . ref($self) . " object...");
	}

	$self->init(); # optional init function for plugins to override global prefs
 
    	$self->log("Returning " . ref($self) . " object...");
    	return($self);
}

sub _initialize {
    
	my ($self, %opts) 	= @_;

	$self->log(ref($self) . "->_initialize()");

	# defaults
	$self->snmp_version('1');
	$self->snmp_retry('3');
	$self->snmp_wait('60');
	$self->snmp_mtu('3000');
	$self->snmp_debug('0');
	$self->snmp_community('public');
	$self->snmp_community_write('');
	$self->snmp_community_read('');

	$self->device_type('');

        $self->file('autobackup/[HOST].cfg');
        $self->err('');

	try {
		foreach my $k (keys %opts) {
			$self->$k($opts{$k});
		}

		$self->snmp_community_write($self->snmp_community) if(!$self->snmp_community_write);
		$self->snmp_community_read($self->snmp_community)  if(!$self->snmp_community_read);

		$self->err("Hostname must be set!") if (!$self->hostname);

		return 0 if($self->err);
	
		$self->snmp();
		$self->plugin($self->_find_plugin());

	} catch Error::Simple with {
		my $error = shift;

		$self->err($error->{'-text'});
		return 0;

	};

}

########################################################

sub snmp {
    	my($self) = @_;
	
	if(!$self->{'_snmp'}) {
		$self->{'_snmp'} = $self->_create_snmp();
	}

	return $self->{'_snmp'};
}

sub tftpserver {
    	my($self, $hostname) = @_;
	
	return $self->{'_tftpserver'} if(!$hostname);

	my $ip = $self->discover_host_address($hostname);
	$self->{'_tftpserver'} = $ip;

	return;
}

sub file {
    	my($self, $file) = @_;

	if(!$file) {
		my $f = $self->{'_file'};
		my $h = $self->hostname;
		$f =~ s/\[HOST\]/$h/g;
		return $f;
	}

	$self->{'_file'} = $file;

	return;
}

sub _create_snmp {
	my $self = shift;
	
	$self->log( ref($self) . "->_create_snmp()");

  	my %snmp_options = (
				-hostname	=> $self->ip,
				-version	=> $self->snmp_version,
				-retries	=> $self->snmp_retry,
				-timeout	=> $self->snmp_wait,
				-maxmsgsize	=> $self->snmp_mtu,
				-debug		=> $self->snmp_debug,
			   );

	if ( $snmp_options{'-version'} eq '3' ) {
    
  		## snmp v3 options
		$snmp_options{'-username'} 	= $self->snmp_user;
		$snmp_options{'-authkey'}  	= $self->snmp_authkey;
    		$snmp_options{'-authpassword'} 	= $self->snmp_authpasswd;

    		if ( $self->{'-snmp_authprotocol'} ) {

      			$snmp_options{'-authprotocol'}	= $self->snmp_authprotocol;
      			$snmp_options{'-privkey'}	= $self->snmp_authkey;
        		$snmp_options{'-privpassword'}	= $self->snmp_authpasswd;
    		}

  	} else {
    
  		## snmp v1/v2 options
    		$snmp_options{'-community'} = $self->snmp_community_read;
  	}

  	## initiate the session
  	my($snmp_session, $snmp_error) = Net::SNMP->session(%snmp_options);
  
	die $self->hostname . " - Could not create SNMP session: $snmp_error" if(!defined($snmp_session));

	return $snmp_session;
}

sub _find_plugin {
	my $self    = shift;

	my %oid = (
			sysdesc => ".1.3.6.1.2.1.1.1.0"
		  );

	$self->log(ref($self) . "->_find_plugin() - Getting device sys_descr");

        $self->snmp->translate([
                              -all     => 0x0
                            ]);
        
   	my $result = $self->snmp->get_request($oid{'sysdesc'});

	if ($self->snmp->error) {
		$self->err("Couldn't connect via SNMP to " . $self->hostname . "! Error was: " . $self->snmp->error);
		return '';
	}
	
	my $desc  = $result->{$oid{'sysdesc'}};

	$self->sys_desc($desc);
	
	my $plugin  = $self->map_desc_to_plugin($desc);
   
	if($plugin) {
		$self->log("Plugin found for " . $self->hostname . " (" . $self->device_type . ")");
		eval "require $plugin";
	
		if ($@) {
			print STDERR "Cannot load plugin $plugin. Cause $@\n";
			return '';
		}

	} else {
		$self->err("Unable to determine plugin for " . $self->hostname . "! sysDesc: " . $self->sys_desc());
	}

	return $plugin; 

}

sub map_desc_to_plugin {
	my $self = shift;
	my $desc = shift;

	$self->log(ref($self) . "->_map_desc_to_plugin() - Searching for plugin matching $desc...");

	my $plugin = '';

        my $types = {
                        'Asante'        => {    'Desc'   => "Asante",
                                                'Module' => "SNMP::Device::Asante"
                                           },
                        'BayStack 350'  => {    'Desc'   => "BayStack 350",
                                                'Module' => "SNMP::Device::BayStack3"
                                           },
                        'BayStack 450'  => {    'Desc'   => "BayStack 450",
                                                'Module' => "SNMP::Device::BayStack"
                                           },
                        'BayStack 470'  => {    'Desc'   => "BayStack 470",
                                                'Module' => "SNMP::Device::BayStack"
                                           },
                        'BayStack 5510' => {    'Desc'   => "BayStack 5510",
                                                'Module' => "SNMP::Device::BayStack"
                                           },
                        'Switch 5510'   => {    'Desc'   => "BayStack 5510",
                                                'Module' => "SNMP::Device::BayStack"
                                           },
                        'Switch 5530-24' => {    'Desc'   => "BayStack 5530",
                                                'Module' => "SNMP::Device::BayStack"
                                           },
                        'C3560'          => {   'Desc'   => "Cisco 3560",
                                                'Module' => "SNMP::Device::Cisco"
                                           },
                        'C3750'         => {    'Desc'   => "Cisco 3750",
                                                'Module' => "SNMP::Device::Cisco"
                                           },
                        'HP28688'       => {    'Desc'   => "HP28688 EtherTwist Hub PLUS",
                                                'Module' => "SNMP::Device::HP"
                                           },
                        'HP28699A'      => {    'Desc'   => "HP28699A EtherTwist Hub PLUS 48",
                                                'Module' => "SNMP::Device::HP"
                                           },
                        'HPJ2603A'      => {    'Desc'   => "HPJ2603A AdvanceStack Hub",
                                                'Module' => "SNMP::Device::HP_AS_HUB"
                                           },
                        'HPJ3210A'      => {    'Desc'   => "HPJ3210A AdvanceStack 10BT Switching Hub",
                                                'Module' => "SNMP::Device::HP_AS_SWITCH"
                                           },
                    };

	foreach my $k (keys %{$types}) {
		if($desc =~ /$k/) {
			$plugin = $types->{$k}->{'Module'};
			$self->device_type($types->{$k}->{'Desc'});
			last;
		}
   	}

	return $plugin;
}

sub hostname {
    	my($self, $hostname) = @_;

	return $self->{'_hostname'} if(!$hostname);

	my $ip = $self->discover_host_address($hostname);

	$self->{'_hostname'} = $hostname;
	$self->ip($ip);

	return;
}

sub log {
    	my($self, $str) = @_;

	return $self->{'_log'} if(!$str);

	my $now_str = localtime;
	my $class   = ref($self);

	$self->{'_log'} .= "$now_str - $class - $str\n";

	return;
}

sub err {
    	my($self, $str) = @_;

	return $self->{'_err'} if(!$str);

	my $now_str = localtime;
	my $class   = ref($self);
	my $ip	    = 'NO HOSTNAME DEFINED';
	$ip	    = $self->hostname if($self->hostname);

	$self->{'_err'} .= "$now_str - $class - $ip - $str\n";

	return;
}

sub discover_host_address {
	my $self     = shift;
	my $hostname = shift;

	if(!$hostname) { 
        	$self->err("Looks like this device doesn't have a hostname!"); 
		return 0;
	}

	my $ip = gethostbyname($hostname);
	
	if(!$ip) {
		$self->err("The following hostname could not be resolved: $hostname");
		return 0;
	}

	$ip = inet_ntoa($ip);
	return $ip;
}


#### LOOK AT THESE #########################
# perhaps changce get_unit_info to _get_unit_info

sub unit_info {
    	my $self = shift;
	
	$self->{'_unit_info'} = $self->get_unit_info if(!$self->{'_unit_info'});
	return $self->{'_unit_info'};
}

sub if_info {
    	my $self = shift;
	$self->{'_if_info'} = $self->get_if_info if(!$self->{'_if_info'});
	return $self->{'_if_info'};
}

sub port_status {
	my $self = shift;
	# OVERRIDE THIS FUNC!!!
	return 0;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SNMP::Device - Perl extension for blah blah blah

=head1 SYNOPSIS

  use SNMP::Device;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for SNMP::Device, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Network Statistician, E<lt>netman@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Network Statistician

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut


