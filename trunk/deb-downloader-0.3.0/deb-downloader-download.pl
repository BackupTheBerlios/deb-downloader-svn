###############################################################################
#
# deb_downloader-download (deb-downloader) 06-08-2004 
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

use Net::HTTP;
use Net::FTP;

use Cwd;
use File::Path;
use File::Copy;


###############################################################################
# Global variables.
###############################################################################

use constant NAME => "deb-downloader-download";
use constant MAIL => "ktala\@badopi.org";
use constant VERSION => "0.3.0";
use constant YES => "Y";
use constant NO => "N";

my %deb_downloader_options = (	
				"debugger"=>"N",
				"skip-downloaded"=>"N",				
				"file"=>"sources.list", 
				"dd-root"=>"./dd-root/",
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
	print("  " . NAME . " --help | --version | --file=filename [--dd-root=directory] [-d|--debug] [--skip-downloaded]  \n");
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
# Formatting the file size in KB, MB, GB or even TB :-).
#
sub human_printing($) {

	my $bytes;
	my @unit = ('Bytes', 'KBytes', 'MBytes', 'GBytes', 'TBytes');
	my $counter;

	$bytes = shift;
	if (length($bytes) == 0) {
		return 0;
	}

	$counter = 0;
	while(($bytes / (1024 ** $counter)) >= 1024) {
		$counter++;
	}

	# return $bytes / (1024 ** ($counter)) . " " . $unit[$counter];
	return sprintf("%.2f", $bytes / (1024 ** ($counter))) . " " . $unit[$counter];

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

sub read_sources($) {

	my @sources;
	my $work;
	my $contents = "";
	my $i;

	@sources = split(/\+/, shift);
	if ($deb_downloader_options{'debugger'} eq YES) {
		for($i=0;$i<scalar(@sources);$i++) {
			debug_print("Source $i --> $sources[$i]\n");
		}
	}

	for($i=0;$i<scalar(@sources);$i++) {
		$work = read_file($sources[$i]);
		if (!$work) {
			print("Sources.list's file named " . $sources[$i] . "not found.\n");
			return 0;
		}
		$contents .= $work;
	}

	return $contents;

}

#
# Validating necessary information needed for right script execution.
#
sub validationsOK() {

    if (length($deb_downloader_options{'file'}) == 0) {
    	print("sources file has not been provided.\n");
		return 0;
	}

	if (length($deb_downloader_options{'dd-root'}) == 0) {
		print("root directory has not been filled.\n");
		return 0;
	}
					 
	return 1;

}

#
# Splits and return server part from an uri entered by param.
#
sub get_protocol_server_part($) {

	my $line = shift;


	if ($line =~ /^\'((?:http|ftp):\/\/[^\/]*)\/[^ ]*\/[^ \/]+\.deb\' [^ ]* [^ ]* [^ ]*/) {
		return $1;
	}
	elsif ($line =~ /^\'((?:http|ftp):\/\/[^\/]*)\/[^ ]*\/[^ \/]+\'/) {
		return $1;
	}
	else {
		print("Incorrect sources.list line.\n");
		print("Program ended abnormally.\n");
		deb_downloader_exit(1);
	}
	
}

#
# Downloading packages read in the file filled in --file option..
#
sub download_packages() {
	
	my $i;
	my $j;
	my $pwd;
	my $old_line;
	my @file_lines;

	$|=1;


    if (!validationsOK()) {
		return 0;
	}

	if (! -e $deb_downloader_options{'dd-root'}) {
		print("Creating deb-download root directory " . $deb_downloader_options{'dd-root'}  . "...");
		mkpath($deb_downloader_options{'dd-root'}) or die return 0;
		print("done\n");
	}

	print("Changing to deb-downloader root directory called " . $deb_downloader_options{'dd-root'} . "...");
	chdir($deb_downloader_options{'dd-root'});
	print("done\n");				
			
	$i = 0;
	while($i<scalar(@sources_list_content_lines)) {
		debug_print("source_line---------> $sources_list_content_lines[$i] \n");
		$old_line = $sources_list_content_lines[$i];
		@file_lines = ();
		$j = 0;
		while($i<scalar(@sources_list_content_lines) && get_protocol_server_part($sources_list_content_lines[$i]) eq get_protocol_server_part($old_line)) {
			debug_print("old value ----> $old_line \n");
			debug_print("part protocol server old value ---->" . get_protocol_server_part($old_line) . "\n");
			debug_print("part protocol server sources line ---->" . get_protocol_server_part($sources_list_content_lines[$i]) . "\n");
			debug_print("source_line--->$sources_list_content_lines[$i]\n");
			$sources_list_content_lines[$i] =~ /^\'(?:ftp|http):\/\/(.*)/;
			$file_lines[$j] = $1;
			$j++;
			$i++;
		}

		debug_print("-----------------------------------------------\n");
		
		if ($old_line =~ /^\'http:\/\/([^\/]*)(\/[^ ]*\/)([^ \/]+)\'/) {
			if (!http_download($1, @file_lines)) {
				return 0;
			}
		}
		elsif ($old_line =~ /^\'ftp:\/\/([^\/]*)(\/[^ ]*\/)([^ \/]+)\'/) {
			if (!ftp_download($1, @file_lines)) {
				return 0;
			}			
		}		
		else {
			return 0;
		}
	}
	
	
	return 1;
}

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
# Files downloading using http protocol and Net::Http module. Each execution 
# of this function uses only one server (list is sorted by server).
#
sub http_download(@) {
	
	my $pwd;
	my $i;
	my $http_connection;
	my $code;
	my $mess;
	my %h;
	my $host_name;
	my @lines;
	my $target_directory;
	my $internal_buffer;
	my $deb_file;
	
	$host_name = shift;
	@lines = @_;	
	
	debug_print("http\$host_name-->$host_name\n");	
	debug_print("http\$host_file-->".join("\n", @lines)."\n");	
	
	print("Protocol------->http.\n");
	
	$pwd = getcwd();
	
	for($i=0;$i<scalar(@lines);$i++) {
		$http_connection = Net::HTTP->new(Host => $host_name) || die "Error openning $host_name http_connection\n";
		debug_print("----->$lines[$i]\n");
		if ($lines[$i] =~ /([^\/]*)(\/[^ ]*\/)([^ \/]+\.deb)\' ([^ ]*) ([^ ]*) ([^ ]*)/) {
			$deb_file = 1;
		}
		elsif($lines[$i] =~ /([^\/]*)(\/[^ ]*\/)([^ \/]+)\'/) {
			$deb_file = 0;
		}
		
		$target_directory = substr($2, 1, length($2)-1);
		
		if ($deb_downloader_options{'skip-downloaded'} eq NO || !-e $pwd.$2.$3) {
			if (! -d $pwd.$2) {
				print("Creating new directory $target_directory...");
				mkpath($target_directory) or die return 0;
				print("done\n");
			}
			
			print("Changing to $target_directory directory ...");
			chdir($target_directory);
			print("done\n");				
			
			print("Downloading file $2$3 " . (($deb_file) ? "(" . human_printing($5) . ")" : "") . "...");
			
			$http_connection->write_request(GET => $2.$3, 'User-Agent' => "Mozilla/5.0");
			($code, $mess, %h) = $http_connection->read_response_headers;
			
			open(DEBFILE,">$3") or die "Error opening output file $2.\n";
			binmode(DEBFILE);
			
			while ($http_connection->read_entity_body($internal_buffer, 1024) > 0) {
				print DEBFILE $internal_buffer;
			}
			close(DEBFILE);	
			print("done\n");
	
			chdir($pwd);
		}	
		else {
			print("File " . $pwd . $2 . $3 . " already downloaded\n");
		}
					
	}
	
	return 1;

}

#
# Files downloading using ftp protocol and Net::Ftp module. Each execution 
# of this function uses only one server (list is sorted by server).
#
sub ftp_download(@) {
	
	my $pwd;
	my $i;
	my $ftp_connection;
	my $host_name;
	my @lines;
	my $target_directory;
	my @files;
	my $deb_file;
			
	$host_name = shift;
	@lines = @_;	
	
	debug_print("ftp\$host_name-->$host_name\n");	
	debug_print("ftp\$host_file-->".join("\n", @lines)."\n");	

	print("Protocol------->ftp.\n");

	$pwd = getcwd();

	$ftp_connection = Net::FTP->new($host_name, Debug => 0)  || die "Error $host_name ftp_connection\n";
	$ftp_connection->login("anonymous",'-anonymous@');
	$ftp_connection->binary();
	
	for($i=0;$i<scalar(@lines);$i++) {
		debug_print("----->$lines[$i]\n");
		if ($lines[$i] =~ /([^\/]*)(\/[^ ]*\/)([^ \/]+\.deb)\' ([^ ]*) ([^ ]*) ([^ ]*)/) {
			$deb_file = 1;
		}
		elsif($lines[$i] =~ /([^\/]*)(\/[^ ]*\/)([^ \/]+)\'/) {
			$deb_file = 0;
		}
		
		if ($deb_downloader_options{'skip-downloaded'} eq NO || !-e $pwd.$2.$3) {
			$target_directory = substr($2, 1, length($2)-1);
			if (! -d $pwd.$2) {
				print("Creating new directory $target_directory...");
				mkpath($target_directory) or die return 0;
				print("done\n");
			}
			print("Changing to $target_directory directory ...");
			chdir($target_directory);
			print("done\n");
			
			print("Downloading file $2$3 " . (($deb_file) ? "(" . human_printing($5) . ")" : "") . "...");
			
		   	$ftp_connection->cwd($2);
		   	@files = $ftp_connection->ls($3);
		   	if (scalar(@files) == 0) {
		   		print("not done\n");
		   		print("File $3 doesn't exists in ftp server $host_name \n");
		   		print("Execute this script with build option again in your Debian.\n");
		   		return 0;
		   	}
		   	$ftp_connection->get($3);
			print("done\n"); 
			
			chdir($pwd);					
			
		}
		else {
			print("File " . $pwd . $2 . $3 . " already downloaded\n");
		}
		
	}
	
	$ftp_connection->quit;
    	
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
		elsif ($_[$i] eq "--skip-downloaded") {
			$deb_downloader_options{'skip-downloaded'} = YES;
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
	# Getting sources.list content
	$sources_list_content = read_sources($deb_downloader_options{'file'});
	debug_print("sources_list-->$sources_list_content\n");
	if (!$sources_list_content) {
		deb_downloader_exit(1);		
	}
	
	# Parse sources.list getting the ftp and http server for downloading.
	if (!parse_sources_list()) {
		print("Error parsing sources.list.\n");
		deb_downloader_exit(1);
	}	
	if (!download_packages()) {
		print("\nPackages downloaded NOK :-(\n\n");
		deb_downloader_exit(1);		
	}		
	print("\nPackages downloaded OK :-)\n\n");
}

deb_downloader_exit(0);
