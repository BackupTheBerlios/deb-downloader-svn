###############################################################################
#
# deb_downloader-install (deb-downloader) 06-08-2004 
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

use constant NAME => "deb-downloader-install";
use constant MAIL => "ktala\@badopi.org";
use constant VERSION => "0.3.0";
use constant YES => "Y";
use constant NO=> "N";
use constant DEFAULT_OUTPUT_DIRECTORY => '/var/cache/apt/archives/';

my %deb_downloader_options = (	
				"debugger"=>"N",
				"file"=>"sources.list", 
				"execute-dist-upgrade"=>"N", 
				"mirror-format"=>"N", 
				"dd-root"=>"./dd-root/",
				"output-directory"=> DEFAULT_OUTPUT_DIRECTORY,
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
	print("  " . NAME . " --help | --version | --file=filename [--dd-root=directory] [--mirror-format] [--execute-dist-upgrade]  [-d|--debug]  \n");
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
# Validations done before install Debian packages.
#
sub validationsOK() {

	my $user;

	# Testing if we are executing the script ina Debian distro.
	if (! -e '/etc/debian_version') {
		print("You are not executing this script's option in a Debian.\n");
		return 0;		
	}

	# Testing if apt-get is installed.
	if (! -e '/usr/bin/apt-get') {
		print("apt-get is not installed in your system. Install it and repeat process execution\n");
		return 0;
	}

	# If execute-dist-upgrade option enabled, user must be root.
	if ($deb_downloader_options{'execute-dist-upgrade'} eq YES) {
		$user = `whoami`;
	   	debug_print("------>" . $user . "\n");
		chomp($user);
		if ($user ne 'root') {
			print("This script option has to be executed as a root user.\n");
	        return 0;
	    }
	}

	# mirror-format option not available if target directory is /var/cache/apt/archives.
	if ($deb_downloader_options{'output-directory'} eq DEFAULT_OUTPUT_DIRECTORY &&
	    $deb_downloader_options{'mirror-format'} eq YES) {
		print("mirror-format option not permitted in " . DEFAULT_OUTPUT_DIRECTORY  . " (default directory).\n");
		return 0;
	}
	
	if (length($deb_downloader_options{'dd-root'}) == 0) {
   	   print("root directory has not been filled.\n");
	   return 0;
	}
	
	if (! -d $deb_downloader_options{'dd-root'}) {
   	   print("Wrong deb_downloader root directory or it doesn't exist.\n");
	   return 0;
	}
	
	if (! -d $deb_downloader_options{'output-directory'}) {
   	   print("Output directory doesn't exist.\n");
	   return 0;
	}

	if (! -w $deb_downloader_options{'output-directory'}) {
   	   print("Output directory is not writable.\n");
	   return 0;
	}

	# Testing if all needed files are available.
	if (! are_all_needed_files_downloaded($deb_downloader_options{'dd-root'})) {
   	   print("There is/are needed file(s) which is/are not downloaded. Please run build and download options.\n");
	   return 0;
	}

	return 1;

}

#
# Checking if all .deb files needed are included in directory structure.
#
sub are_all_needed_files_downloaded($) {

	my @uris_list;
	my $root_directory;
	my $i;

	$root_directory = shift;
	debug_print("\$root_directory before ----> $root_directory\n");
	debug_print("\$root_directory after ----> $root_directory\n");

	@uris_list = split(/\n+/, read_file($deb_downloader_options{'file'}));
	unlink 'deb_downloader_uris_dist_upgrade.txt';
	for($i=0;$i<scalar(@uris_list);$i++) {
		if ($uris_list[$i] =~ /^\'(?:http|ftp):\/\/[^\/]*\/([^ ]*\/[^ \/]+.*)' [^ ]* [^ ]* [^ ]*/) {
			debug_print("file---->$root_directory$1.\n");
			if (! -e "$root_directory$1") {
				return 0;
			}
		}
		elsif ($uris_list[$i] =~ /^\'(?:http|ftp):\/\/[^\/]*\/([^ ]*\/[^ \/]+.*)'/) {
			debug_print("file---->$root_directory$1.\n");
			if (! -e "$root_directory$1") {
				return 0;
			}
		}
	}
	
	return 1;

}

#
# Copying the .deb files from source directory to target directory.
#
sub copy_files {

	my $source_directory;
	my $target_directory;
	my @files;
	my $i;
	my $pathname;
	my $filename;
	my $control_line;

	$source_directory = shift;
	$target_directory = shift;
	debug_print("source_directory--->$source_directory\n");
	debug_print("target_directory--->$target_directory\n");

	opendir(SOURCE_DIR, $source_directory) or die return 0;
	debug_print("sources_file--->$deb_downloader_options{'file'}\n");
	@files = split('\n', read_file($deb_downloader_options{'file'}));
	for($i=0;$i<scalar(@files);$i++) {
		if ($files[$i] =~ /^\'(?:http|ftp):\/\/[^\/]*\/([^ ]*\/)([^ \/]+.*)' [^ ]* [^ ]* [^ ]*/) {
			$pathname = $1;
			$filename = $2;
			$control_line = 0;
		}
		elsif ($files[$i] =~ /^\'(?:http|ftp):\/\/[^\/]*\/([^ ]*\/[^ \/]+.*)'/) {
			$pathname = $1;
			$filename = $2;
			$control_line = 1;
		}
		else {
			print("Error processing line $files[$i].\n");
			return 0;
		}
		
		debug_print("file--->$deb_downloader_options{'dd-root'}$pathname$filename\n");
		debug_print("path--->$target_directory$filename\n");
		if ($deb_downloader_options{'mirror-format'} eq YES) {
			if (! -e "$target_directory$pathname") {
	       		print("Creating new directory $target_directory$pathname...");
		        mkpath($target_directory.$pathname) or die return 0;
		 	    print("done\n");
			}
	       	print("Copying file $target_directory$pathname$filename...");
			copy("$deb_downloader_options{'dd-root'}$pathname$filename", "$target_directory$pathname$filename");
			print("done\n");
		}
		else {
			if (!$control_line) {
	       		print("Copying file $target_directory$filename...");
				copy("$deb_downloader_options{'dd-root'}$pathname$filename", "$target_directory$filename");
				print("done\n");
			}
		}
	}

	close(SOURCE_DIR);
	
	return 1;
}

#
# Installing .deb files in our computer.
#
sub install_packages {

	my $user;
	my $files_copied_ok;

    if (!validationsOK()) {
		return 0;
	}
				
	# Copy all .deb files into output-directory.
	$files_copied_ok = copy_files($deb_downloader_options{'dd-root'}, $deb_downloader_options{'output-directory'});
	if (!$files_copied_ok) {
   	   print("Files can not be copied ok.\n");
	   return 0;
	}

	if ($deb_downloader_options{'execute-dist-upgrade'} eq YES) {
		# Execute apt-get dist-upgrade. 
		 debug_print('apt-get dist-upgrade executed.\n');
		if (system("/usr/bin/apt-get dist-upgrade") ne "0") {
   	   		print("Error executing apt-get dist-upgrade.\n");
			return 0;
		}
	}

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
		elsif ($_[$i] =~ /--dd-root=((?:[^ ]*\+?)+)/) {
			$deb_downloader_options{'dd-root'} = $1;
			if ($deb_downloader_options{'dd-root'} =~ /.*[^\/]/) {
				$deb_downloader_options{'dd-root'} .= '/';
			}
		}
		elsif ($_[$i] =~ /--output-directory=((?:[^ ]*\+?)+)/) {
			$deb_downloader_options{'output-directory'} = $1;	
		}
		elsif ($_[$i] =~ /--execute-dist-upgrade/) {
			$deb_downloader_options{'execute-dist-upgrade'} = YES;
		}
		elsif ($_[$i] eq "--mirror-format") {
			$deb_downloader_options{'mirror-format'} = YES;
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
	if (!install_packages()) {
		print("\nPackages installed NOK :-(\n\n");
		deb_downloader_exit(1);		
	}		
	print("\nPackages installed OK :-)\n\n");
}

deb_downloader_exit(0);
