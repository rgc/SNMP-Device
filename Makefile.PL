use 5.008005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SNMP::Device',
    VERSION_FROM      => 'lib/SNMP/Device.pm', # finds $VERSION
    PREREQ_PM         => {
			   'Bit::Vector' => 0,
			   'Error'	 => 0,
			   'Net::SNMP'	 => 0,
			   'Socket'	 => 0,
			 },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/SNMP/Device.pm', # retrieve abstract from module
       AUTHOR         => 'Network Statistician <netman@localdomain>') : ()),
);
