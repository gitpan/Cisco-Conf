# -*- perl -*-
#
#
#   Cisco::Conf - a Perl package for configuring Cisco routers via TFTP
#
#
#   Copyright (C) 1998    Jochen Wiedmann
#                         Am Eisteich 9
#                         72555 Metzingen
#                         Germany
#
#                         Phone: +49 7123 14887
#                         Email: joe@ispsoft.de
#
#   All rights reserved.
#
#   You may distribute this module under the terms of either
#   the GNU General Public License or the Artistic License, as
#   specified in the Perl README file.
#

package Cisco::Conf::Install;

use strict;

require ExtUtils::MakeMaker;
require Cisco::Conf;
require Socket;


$Cisco::Conf::Install::VERSION = '0.01';


sub Install ($$$) {
    my($class, $file, $prefix) = @_;

    my $config = { 'hosts' => {} };
    my $searchSub = sub {
	my($prog) = @_;
	my $dir;
	foreach $dir (split(/:/, $ENV{'PATH'})) {
	    if (-x "$dir/$prog") {
		return "$dir/$prog";
	    }
	}
	undef;
    };

    $config->{'etc_dir'} = ExtUtils::MakeMaker::prompt
	("\nWhich directory should be used for router configurations?" .
	 "\n", "$prefix/etc");
    if (! -d $config->{'etc_dir'}) {
	if (ExtUtils::MakeMaker::prompt
	        ("\nA directory " . $config->{'etc_dir'} . " does not exist." .
		 "\n Create it?",
		 "y") !~ /y/i) {
	    die "etc_dir not a valid directory, cannot continue.";
	}
    } else {
	my $target = $config->{'etc_dir'} . "/configuration";
	if (-f $target) {
	    my $reply = ExtUtils::MakeMaker::prompt
		("\nA file $target already exists. Read configuration" .
		 "\nfrom this file?", "y");
	    if ($reply =~ /y/i) {
		$config = Cisco::Conf->_ReadConfigFile($target);
	    }
	}
    }

    if (!exists($config->{'tftp_dir'})) {
	my $tftpdir = $config->{'etc_dir'};
	if ($tftpdir =~ /\/etc$/) {
	    $tftpdir =~ s/\/etc$/\/tftp/;
	} else {
	    $tftpdir = "/tftpboot";
	}
    
	$config->{'tftp_dir'} = ExtUtils::MakeMaker::prompt
	    ("\nWhich directory should be used for transferring files from or to" .
	     "\nthe routers?",
	     $tftpdir);
	if (! -d $config->{'tftp_dir'}) {
	    if (ExtUtils::MakeMaker::prompt
	        ("\nA directory " . $config->{'tftp_dir'} .
		 " does not exist.\n Create it?",
		 "y") !~ /y/i) {
		die "tftp_dir not a valid directory, cannot continue.";
	    }
	}
	if ($config->{'tftp_dir'} eq $config->{'etc_dir'}) {
	    die "etc_dir and tftp_dir must be different";
	}
    }

    if (!exists($config->{'editors'})) {
	my $editors = '';
	my $e;
	foreach $e (qw(vi emacs joe)) {
	    my $prog = &$searchSub($e);
	    if ($prog) {
		if (length($editors)) {
		    $editors .= ' ';
		}
		$editors .= $prog;
	    }
	}
	$editors = ExtUtils::MakeMaker::prompt
	    ("\nEnter a list of valid editors used for modifying router" .
	     "\nconfigurations:", $editors);
	if (!$editors) {
	    die "No valid editor configured.";
	}
	$editors =~ s/^\s+//;
	$editors =~ s/\s+$//;
	$config->{'editors'} = [split(' ', $editors)];
    }

    if (!exists($config->{'ci'})) {
	my $ci = &$searchSub("ci");
	if ($ci) {
	    $ci = "$ci -l";
	} else {
	    $ci = 'none';
	}
	$ci = ExtUtils::MakeMaker::prompt
	    ("\nEnter a command for passing router configurations to the" .
	     "\nrevision control system:", $ci);
	$config->{'ci'} = ($ci  &&  $ci ne 'none') ? $ci : undef;
    }

    if (!exists($config->{'local_addr'})) {
	my $local_addr = eval {
	    require Sys::Hostname;
	    Sys::Hostname::hostname();
	};
	if ($local_addr) {
	    if (!Socket::inet_aton($local_addr)) {
		undef $local_addr;
	    } else {
		$local_addr
		    = Socket::inet_ntoa(Socket::inet_aton($local_addr));
		if ($local_addr =~ /^127\./) {
		    undef $local_addr;
		}
	    }
	}
	if (!$local_addr) {
	    $local_addr = 'none';
	}
	$local_addr = ExtUtils::MakeMaker::prompt
	    ("\nEnter the IP address of the local TFTP server:", $local_addr);
	if ($local_addr) {
	    if ($local_addr eq 'none') {
		undef $local_addr;
	    } elsif (!Socket::inet_aton($local_addr)) {
		undef $local_addr;
	    } else {
		$local_addr
		    = Socket::inet_ntoa(Socket::inet_aton($local_addr));
		if ($local_addr =~ /^127\./) {
		    undef $local_addr;
		}
	    }
	}
	if (!$local_addr) {
	    die "The TFTP servers IP address must be valid, resolvable and not"
		. " refer to the loopback device.";
	}
	$config->{'local_addr'} = $local_addr;
    }

    if (!exists($config->{'tmp_dir'})) {
	$config->{'tmp_dir'} = ExtUtils::MakeMaker::prompt
	    ("\nEnter a directory for creating temporary files:", "/tmp");
    }

    Cisco::Conf->_SaveConfigFile($file, $config);

    $config;
}


1;

__END__

=head1 NAME

Cisco::Conf::Install - Create a configuration file for the Cisco::Conf module


=head1 SYNOPSIS

    use Cisco::Conf::Install;
    Cisco::Conf::Install->Install($file, $prefix);

=head1 DESCRIPTION

This module is used to create configuration files for the Cisco::Conf
module. It holds a single class method, I<Install>, that attempts to
guess the system defaults and queries the user for all settings.

The prefix C<$prefix> is used as a default for certain directory settings.
The configuration is saved as C<$file>. A hash ref with all configuration
is returned, the method dies in case of errors.

The configuration file initially holds an empty list of routers. Use
the I<Add> method or the C<-a> option of the I<cisconf> script to
add routers.

=head1 AUTHOR AND COPYRIGHT

This module is

    Copyright (C) 1998    Jochen Wiedmann
                          Am Eisteich 9
                          72555 Metzingen
                          Germany

                          Phone: +49 7123 14887
                          Email: joe@ispsoft.de

All rights reserved.

You may distribute this module under the terms of either
the GNU General Public License or the Artistic License, as
specified in the Perl README file.


=head1 SEE ALSO

L<cisconf(1)>, L<Cisco::Conf(3)>

=cut


