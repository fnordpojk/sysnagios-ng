#!/usr/bin/perl

# File:    $Id: getconfigs.cgi,v 1.21 2009/06/05 08:01:25 xz1862 Exp $
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use CGI qw/:standard/;
use Fcntl ':flock';
use File::Find;
use File::Copy;

our $DEBUG=0;
$TEMPDIR="/tmp/$$.tempdir";
mkdir $TEMPDIR;

sub debug {
	my($line)=@_;
	if($DEBUG gt 0){
		print "$line\n";
	}
}

sub readconfig {
	my($configfile)=@_;
	debug("readconfig $configfile");

	open(CFG, "<$configfile");

	foreach $cfg (<CFG>){
		chomp($cfg);
		$cfg=~s/#.*$//g;
		if(length($cfg)>1){
			($key, $value)=split(/=/, $cfg);
			if(length($value)>0){
				$config{$key}=$value;
			}
		}
	}
	return %config;
}

if($DEBUG>1){
	%config=readconfig("/home/xz1862/pkg/sysnagios_server/sysnagios.conf");
	use Data::Dumper;
	print Dumper(\%config);
} else {
	%config=readconfig("/etc/sysnagios.conf");
}

$sysnagios_home=$config{'SYSNAGIOS_HOME'};
debug("sysnagios_home=$sysnagios_home");

# Expect host
my $host = param('host') if param('host');
my $ip = param('ip') if param('ip');
# Look for proxy too.
my $tempproxy = param('proxy') if param('proxy');

$port=$config{'NRPE_PORT'};
my $port=param('port') if param('port');

$ssl="SSL";
my $ssl=param('ssl') if param('ssl');

# Prevent connecting to unallowed proxy hosts.
foreach $proxyname ( split(/,/, $config{'PROXY_HOSTS'}) ){
	if("$proxyname" eq "$tempproxy"){
		$proxy=$proxyname;
	}
}

# Protection against evil url-hacking
$host=~s/\///g;
$host=~s/;//g;
$proxy=~s/\///g;
$proxy=~s/;//g;
$port=~s/\///g;
$port=~s/;//g;
$ssl=~s/\///g;
$ssl=~s/;//g;

# Changed fixedscale checking since empty param was returning undef from CGI.pm
my @paramlist = param();

print header(-type => "text/html", -expires => 0);
print start_html(-id=>"sysnagios",-title=>'Sysnagios get configuration');
print "<H2>This is the output from sysnagios getconfigs</H2>\n";
print "If any error is indicated, please contact your Nagios administrator <P>\n";


$reload=0;
foreach $host (split(/\s+/, $host)){
	if (length($host)>0){
		# Get the config

		print "<PRE>\n";
		print "$host\n";

		# Handle proxying...
		if($proxy eq ""){
			debug("exec: $sysnagios_home/getconfigs.sh $ip");
			if( "$ip" ne "" ){
				$getconfigs=`$sysnagios_home/getconfigs.sh $ip:$port:$ssl`;
			} else {
				$getconfigs=`$sysnagios_home/getconfigs.sh $host:$port:$ssl`;
			}

			print "$getconfigs\n";
			# This should be put in a subroutine some day!
			# Extract the filename from getconfigs output
			@filename=split(/\n/, $getconfigs);
			$filename="";
			$OK="";
			foreach $line (@filename){ 
				if ($line=~/^.*_services.cfg/){
					$filename=$line;
					push(@files,$line);
					$hostname=$filename;
					$hostname=~s/^(.+)_services.cfg/$1/;
					print `$config{HOST_CONTROL_COMMAND} $hostname`;
				}
				if($line=~/^Config OK$/){
					$OK="OK";
					#$reload=1;
				}
			}

		} else { #Actually THIS is where proxying is handled.
			print "Connect to proxy host $proxy\n";

			debug("$config{'PROXY_SSH'} -l  $config{'PROXY_USER'} $proxy $config{'PROXY_SYSNAGIOS_HOME'}/getconfigs.sh $host");
			$getconfigs=`$config{"PROXY_SSH"} -l $config{'PROXY_USER'} $proxy $config{'PROXY_SYSNAGIOS_HOME'}/getconfigs.sh $host:$port:$ssl`;
			print $getconfigs;

	
			# Kolla om hamtningen gick bra pa proxy-servern
			# Hamta i sa fall hem filerna till denna servern.
			@filename=split(/\n/, $getconfigs);
			$filename="";
			$OK="";
			foreach $line (@filename){ 
				if ($line=~/^.*_services.cfg/){
						push(@files,$line);
					}
					if($line=~/^Config OK$/){
						$OK="OK";
					}
			}
			if($OK eq "OK"){
				print "Config OK at the proxy\n";
				# Used to determine wether to reload or not;
				foreach $filename (@files){
					$hostname=$filename;
					$hostname=~s/^(.+)_services.cfg/$1/;
					print "Transferring $filename\n";
					if ( -f "$config{CONFIG_DIR}/$filename" ){
						copy("$config{CONFIG_DIR}/$filename", "$TEMPDIR/");
					}
						
					# SCP the file
					`$config{'PROXY_SCP'} $config{'PROXY_USER'}\@$proxy:$config{'PROXY_CONFIG_DIR'}/$filename $config{'CONFIG_DIR'}`;

					#do syntax check
					$cfg_ok=0;
					foreach $line (`$config{NAGIOS_BIN} -v $config{NAGIOS_CFG}`){
						if ( $line=~/Things look okay/ || $line=~/^Config OK$/ ){
							$cfg_ok=1;
							print "Syntax OK\n";
							$reload=1;
							# Do post install check.
							print `$config{HOST_CONTROL_COMMAND} $hostname`;
						}
					}
					if ($cfg_ok==0){
						if ( -f "$TEMPDIR/$filename" ){
							copy("$TEMPDIR/$filename", "$config{CONFIG_DIR}");
						}
						print "Syntax Error\n";
						print "Revoking to old file\n";
					}
				}
			}
		}
	
		print "</PRE>\n";
	
		#if( "$filename" ne "" ){
			#$host=`sed -n '/define host\s*{/,/}/{p}' $config{'CONFIG_DIR'}/$filename | awk '/host_name/{print \$2}'`;
			#print "$config{'HOST_CONTROL_COMMAND'} $host\n";
			#$hostcheck=`$config{'HOST_CONTROL_COMMAND'} $host`;
			#print "done\n";
			#print "$hostcheck <P>\n";
		#} 
	} else {
		print "<H1>No hostname specified</H1>\n";
	}
}
if ($reload>0){
	print "Reloading config<P>\n";
	print `eval $config{NAGIOS_RELOAD_CMD}`;
	#print "eval $config{NAGIOS_RELOAD_CMD} <P>\n";
}
	
print "<A HREF='javascript:window.history.go(-1)'>Done</A>";
print end_html;

`rm -rf $TEMPDIR`;
