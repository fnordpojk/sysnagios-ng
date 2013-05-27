#!/usr/bin/perl

$DEBUG=0;

sub readconfig {
	my($configfile)=@_;
	#debug("readconfig $configfile");

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

print "Content-Type: text/html; charset=ISO-8859-1\n\n";

readconfig("/etc/sysnagios.conf");

print "<SELECT NAME='proxy' class='NavBarSearchItem'> \n";
print "<OPTION selected VALUE=''>No proxy</OPTION> \n";
foreach $proxyname ( split(/,/, $config{'PROXY_HOSTS'}) ){
	print"<OPTION VALUE=\'$proxyname\'>$proxyname</OPTION>\n";
}

print "</SELECT> \n";

