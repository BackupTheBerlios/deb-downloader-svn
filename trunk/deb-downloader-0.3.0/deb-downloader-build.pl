###############################################################################
#
# deb_downloader-build (deb-downloader) 06-08-2004 
#
#	Utility for downloading packages in a computer with no Debian 
#       installed and apt-get then in our favourite flavour of Debian.
#
# Copyright (C) 2004 Miquel Oliete <ktala@badopi.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
#
###############################################################################

###############################################################################
#
# History : 
#
# 	06-08-2004 - deb_downloader init.
# 	07-08-2004 - http and ftp transmission implementation.
# 	11-09-2004 - deb_downloader version 0.1.7.
# 	18-09-2004 - deb_downloader version 0.1.8.
# 	19-09-2004 - deb_downloader version 0.1.9.
# 	20-09-2004 - deb_downloader version 0.1.10.
# 	21-09-2004 - deb_downloader version 0.1.11.
# 	06-10-2004 - deb_downloader version 0.1.12.
# 	07-10-2004 - deb_downloader version 0.1.13.
# 	10-10-2004 - deb_downloader version 0.1.14.
# 	19-10-2004 - deb_downloader version 0.1.15.
#
#
###############################################################################

###############################################################################
#
# Notes : 
# 
###############################################################################

use strict;

use Cwd;
use File::Path;
use File::Copy;


###############################################################################
# Global variables.
###############################################################################

use constant NAME => "deb-downloader-build";
use constant MAIL => "ktala\@badopi.org";
use constant VERSION => "0.3.0";
use constant YES => "Y";
use constant NO=> "N";

my %deb_downloader_options = (	
				"debugger"=>"N",
				"file"=>"sources.list", 
				"skip-update"=>"N", 
				"help"=>"N",
				"version"=>"N");
			      
my $sources_list_content = "";
my @sources_list_content_lines = ();
my $execution_directory = "";

###############################################################################
# Functions.
###############################################################################

#
# Printing deb-downloader version.
#
sub print_version() {

	print("\n");
	print(NAME . " " . VERSION . " Copyright (C) 2004 Miquel Oliete <" . MAIL . ">\n");
	print("\n");
	print("This program is free software; you can redistribute it and/or modify\n");
	print("it under the terms of the GNU General Public License as published by\n");
	print("the Free Software Foundation; version 2 of the License.\n");
	print("\n");

}

#
# Printing deb-downloader usage.
#
sub print_usage() {

	print_version();
	print("\n");
	print("Usage : \n");
	print("\n");
	print("  " . NAME . " --help | --version | --file=filename [--skip-update] [-d|--debug]  \n");
	print("\n");
	
}

#
# Printing text if execution is in debug mode.
#
sub debug_print($) {
	
	if ($deb_downloader_options{'debugger'} eq YES) {
		print(shift);
	}
	
}

#
# Exiting from deb-downloader.
#
sub deb_downloader_exit($) {

	my $exit_code;

	$exit_code = shift;
	cwd($execution_directory);
	if ($exit_code != 0) {
		print_usage();
	}
	exit($exit_code);
}

#
# Reading the file which name is in param.
#
sub read_file($) {

	my $filename;
	my $text;

	$filename = shift;

	debug_print("filename--->$filename\n");
	if (! -e $filename) {
		return 0;
	}

	open(FILE,$filename) or die return 0;

	$text = "";
	while(<FILE>) {
		$text .= $_;
	}

	close(FILE);

	return $text;

}
																

#
# Writting a file which name is in first param and context i second one.
#
sub write_file(@) {

	my $filename;
	my $text;

	if (scalar(@_) != 2) {
		return 0;
	}
	
	$filename = shift;
	$text = shift;

	open(FILE,">".$filename) or die return 0;
	print FILE $text;
	close(FILE);

	return 1;

}

#
# With this method we know if the script in executed in a debian or
# based debian distro or not and if apt-get is installed.
#
sub is_debian_ready() {

	if (! -e '/etc/debian_version') {
		print("You are not executing this script's option in a Debian.\n");
		return 0;		
	}

	if (! -e '/usr/bin/apt-get') {
		print("apt-get is not installed in your system. Install it and repeat process execution\n");
		return 0;
	}

	return 1;
	
}

#
# Validating necessary information needed for right script execution.
#
sub validationsOK() {

	my $user;

    if (length($deb_downloader_options{'file'}) == 0) {
    	print("sources file has not been provided.\n");
		return 0;
	}

	if (!is_debian_ready()) {
		return 0;
	}

	if ($deb_downloader_options{'skip-update'} eq NO) {
		$user = `whoami`;
	   	debug_print("------>" . $user . "\n");
		chomp($user);
		if ($user ne 'root') {
			print("This script option has to be executed as a root user.\n");
	        return 0;
	    }
	}
																													

	return 1;

}

#
# Read files which contains packages definitions and write them in the
# uris file joining access protocol and file path.
#
sub get_resume_files() {

	my $lines;
	my @sources_list_lines;
	my @files;
	my $i;
	my %servers;

	# Read /etc/apt/sources.list and get the servers with its access protocol.
	@sources_list_lines = split("\n", read_file("/etc/apt/sources.list"));
	debug_print("scalar---->".scalar(@sources_list_lines)."\n");
	for($i=0;$i<scalar(@sources_list_lines);$i++) {
		if ($sources_list_lines[$i] =~ /^(?:deb|deb-src) +(ftp|http):\/\/([^\/]+).*/) {
			debug_print("\$1----------------->$1\n");
			debug_print("\$2----------------->$2\n");
			$servers{"$2"} = $1;
		}
	}

	# Read /var/lib/apt/lists files and add access protocol.
	opendir(DIRECTORY,"/var/lib/apt/lists/") or die return 0;
	@files = readdir(DIRECTORY);
	closedir(DIRECTORY);
	debug_print("scalar---->".scalar(@files)."\n");


	# Build lines.
	$lines = "";
	for($i=0;$i<scalar(@files);$i++) {
		debug_print("$files[$i]\n");
		if ($files[$i] =~ /((((?:ftp|http)[^\_]+)\_[^\_]+)+)/) {
			debug_print("\$1----------------->$1\n");
			debug_print("\$2----------------->$2\n");
			debug_print("\$3----------------->$3\n");
			$lines .= "'" . $servers{"$3"} . "://";
			$files[$i] =~ s/\_/\//g;
			$lines .= $files[$i] . "'\n";
		}
	}
	
	# return list.
	debug_print("lines-->$lines\n");
	return $lines;

}

#
# Build uris list for downloading packages with deb-downloader-download.
#
sub build_list() {

	my $uris;
	my @uris_list;
	my $i;
	my $question;


	if (!validationsOK()) {
		return 0;
	}
									  
	if ($deb_downloader_options{'skip-update'} eq NO) {
		if (system("/usr/bin/apt-get update") ne "0") {
			print("Error executing apt-get update. Check it manually.\n");
			return 0;
		}
	}

	$uris = get_resume_files();
	
	if (system("/usr/bin/apt-get dist-upgrade --assume-yes --print-uris  > deb_downloader_uris_dist_upgrade.txt") ne "0") {
			unlink 'deb_downloader_uris_dist_upgrade.txt';
			print("Error executing apt-get dist-upgrade --assume-yes --print-uris. Check it manually.\n");
			return 0;
	}

	@uris_list = split(/\n+/, read_file('deb_downloader_uris_dist_upgrade.txt'));
	unlink 'deb_downloader_uris_dist_upgrade.txt';
	for($i=0;$i<scalar(@uris_list);$i++) {
		if ($uris_list[$i] =~ /^\'(?:http|ftp):\/\/[^\/]*\/[^ ]*\/[^ \/]+\.deb\' [^ ]* [^ ]* [^ ]*/) {
			$uris .= $uris_list[$i] . "\n";
		}
	}

	if (-e $deb_downloader_options{'file'}) {
		print("File named $deb_downloader_options{'file'} already exists. Do you want to overwrite it (y/N) ?");
		$question = <STDIN>;
		chomp($question);
		debug_print("\$question---->$question\n");
		if (uc($question) ne YES) {
			print("Proces stopped by user.\n");
			return 0;
		}
		
	}
	
	write_file($deb_downloader_options{'file'}, $uris);
	
	
	return 1;
	
}

#
# Parses sources.list content for using resume files access protocol.
#
sub parse_sources_list() {
	
	my @lines;
	my $i;
	my $line_index;
	
	@lines = split(/\n+/, $sources_list_content);
	$line_index = 0;
	for($i=0;$i<scalar(@lines);$i++) {
		if ($lines[$i] =~ /((?:ftp|http):\/\/.*)/) {
			$sources_list_content_lines[$line_index] = $lines[$i];
			$line_index++;			
			debug_print("$lines[$i]--->Source line\n");
			
		}
		elsif ($lines[$i] =~ /^#.*/) {
			debug_print("$lines[$i]--->Comentary\n");
		}
		else {
			debug_print("$lines[$i]--->Error\n");
			return 0;
		}
	}
	
	if ($line_index == 0) {
		print("No valid sentence in sources.list file.\n");
		return 0;
	}
	
	@sources_list_content_lines = sort @sources_list_content_lines;
	
	return 1;
	
}

#
# Parameters validation.
#
sub validate_and_get_parameters(@) {
	
	my $i;
	
	if (scalar(@_) == 0) {
		return 0;
	}
	
	for($i=0;$i<scalar(@_);$i++) {
		debug_print("dist--->execute-dist" . "\n");
		debug_print("--->  $_[$i]" . "  ------"  ."\n");
		if ($_[$i] =~ /^(?:-d|--debug)$/) {
			$deb_downloader_options{'debugger'} = YES;
		}
		elsif ($_[$i] =~ /--file=((?:[^ ]*\+?)+)/) {
			debug_print("Files-->$1\n");
			$deb_downloader_options{'file'} = $1;	
		}
		elsif ($_[$i] eq "--skip-update") {
			$deb_downloader_options{'skip-update'} = YES;
		}
		elsif ($_[$i] eq "--help") {
			$deb_downloader_options{'help'} = YES;
		}
		elsif ($_[$i] eq "--version") {
			$deb_downloader_options{'version'} = YES;
		}
		else {
			return 0;
		}
	}
	
	return 1;	
	
}

###############################################################################
# Main body
###############################################################################

$execution_directory = getcwd();

if (!validate_and_get_parameters(@ARGV)) {
	print("Error in parameters.\n");
	deb_downloader_exit(1);	
}

# Action to do.

if ($deb_downloader_options{'help'} eq YES) {
	print_usage();
}
elsif ($deb_downloader_options{'version'} eq YES) {
	print_version();
}
else {
	if (!build_list()) {
		print("\nPackages list built NOK :-(\n\n");
		deb_downloader_exit(1);
	}
	print("\nPackages list built OK :-)\n\n");
}

deb_downloader_exit(0);
