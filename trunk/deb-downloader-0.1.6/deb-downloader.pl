###############################################################################
#
# deb_downloader 06-08-2004 
#
#	Utility for downloading packages in a computer with no Debian 
#       installed and apt-get then in our favourite flavour of Debian.
#
# Copyright (C) 2004 Miquel Oliete <miqueloliete@softhome.net>
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
# Notes : 
# 
# - Pendent mirar que passa amb la connexió del HTTP (s'ha d'obrir cada vegada).
# - Control·lar l'existencia de l'arxiu al servidor per transferències http.
# - Formatejar a la sortida els tamanys dels arxius amb dos decimals només.
#
###############################################################################

use strict;

use Net::HTTP;
use Net::FTP;

use Cwd;
use File::Path;


###############################################################################
# Global variables.
###############################################################################

use constant NAME => "deb_downloader";
use constant VERSION => "0.1.6";
use constant BUILD_LIST => "build_list";
use constant DOWNLOAD_PACKAGES => "download_packages";
use constant YES => "Y";
use constant NO=> "N";

my %deb_downloader_options = (	"debugger"=>"N",
   				"option"=>"", 
				"file"=>"sources.list", 
				"skip-update"=>"N", 
				"help"=>"N",
				"version"=>"N");
			      
my $sources_list_content = "";
my @sources_list_content_lines = ();

###############################################################################
# Functions.
###############################################################################

sub print_version() {

	print("\n");
	print(NAME . " " . VERSION . " Copyright (C) 2004 Miquel Oliete <miqueloliete\@softhome.net>\n");
	print("\n");
	print("This program is free software; you can redistribute it and/or modify\n");
	print("it under the terms of the GNU General Public License as published by\n");
	print("the Free Software Foundation; version 2 of the License.\n");
	print("\n");

}

sub print_usage() {

	print_version();
	print("\n");
	print("Usage \n");
	print("\n");
	print("  " . NAME . " --help | --version | --option=build|download --file=filename [--skip-update] [-d|--debug]  \n");
	print("\n");
	
}

sub debug_print($) {
	
	if ($deb_downloader_options{'debugger'} eq YES) {
		print(shift);
	}
	
}

sub human_printing($) {

	my $bytes;
	my @unit = ('Byte(s)', 'KByte(s)', 'MByte(s)', 'GByte(s)', 'TByte(s)');
	my $counter;

	$bytes = shift;
	if (length($bytes) == 0) {
		return 0;
	}

	$counter = 0;
	while(($bytes / (1024 ** $counter)) >= 1024) {
		$counter++;
	}

	return $bytes / (1024 ** ($counter)) . " " . $unit[$counter];

}

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

sub build_list() {

	my $apt_get_output;
	my $uris;
	my @uris_list;
	my $i;
	my $question;

	if (! -e '/etc/debian_version') {
		print("You are not executing this script's build option in a Debian.\n");
		return 0;		
	}

	if (! -e '/usr/bin/apt-get') {
		print("apt-get is not installed in your system. Install it and repeat process execution\n");
		return 0;
	}

	if (length($deb_downloader_options{'file'}) == 0) {
		print("sources file has not been provided.\n");
		return 0;
	}

	if ($deb_downloader_options{'skip-update'} eq NO) {
		if (system("apt-get update") ne "0") {
			print("Error executing apt-get update. Check it manually.\n");
			return 0;
		}
	}

	$uris = get_resume_files();
	
	if (system("apt-get dist-upgrade --assume-yes --print-uris > deb_downloader_uris_dist_upgrade.txt") ne "0") {
			system("rm deb_downloader_uris_dist_upgrade.txt");
			print("Error executing apt-get dist-upgrade --assume-yes --print-uris. Check it manually.\n");
			return 0;
	}
	# @uris_list = split(/\n+/, $apt_get_output);
	@uris_list = split(/\n+/, read_file('deb_downloader_uris_dist_upgrade.txt'));
	system("rm deb_downloader_uris_dist_upgrade.txt");
	for($i=0;$i<scalar(@uris_list);$i++) {
		if ($uris_list[$i] =~ /^\'(?:http|ftp):\/\/[^\/]*\/[^ ]*\/[^ \/]+\.deb\' [^ ]* [^ ]* [^ ]*/) {
			$uris .= $uris_list[$i] . "\n";
		}
	}

	if (-e $deb_downloader_options{'file'}) {
		$question = NO;
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

sub get_protocol_server_part($) {

	my $line = shift;
	
	if ($line =~ /(?:^\'((?:http|ftp):\/\/[^\/]*\/[^ ]*\/)[^ \/]+\.deb\' [^ ]* [^ ]* [^ ]*)|(?:^\'(?:http|ftp):\/\/[^\/]*\/[^ ]*\/[^ \/]+\')/) {
		return $1;
	}
	else {
		print("Incorrect sources.list line.\n");
		print("Program ended abnormally.\n");
		exit 1;
	}
	
}

sub download_packages() {
	
	my $i;
	my $j;
	my $pwd;
	my $old_line;
	my @file_lines;
	
	$i = 0;
	while($i<scalar(@sources_list_content_lines)) {
		$old_line = $sources_list_content_lines[$i];
		@file_lines = ();
		$j = 0;
		while($i<scalar(@sources_list_content_lines) && get_protocol_server_part($sources_list_content_lines[$i]) == get_protocol_server_part($old_line)) {
			$sources_list_content_lines[$i] =~ /^\'(?:ftp|http):\/\/(.*)/;
			$file_lines[$j] = $1;
			$j++;
			$i++;
		}
		
		# if ($old_line =~ /^\'http:\/\/([^\/]*)(\/[^ ]*\/)([^ \/]+\.deb)\' ([^ ]*) ([^ ]*) ([^ ]*)/) {
		if ($old_line =~ /^\'http:\/\/([^\/]*)(\/[^ ]*\/)([^ \/]+)\'/) {
			if (!http_download($1, @file_lines)) {
				return 0;
			}
		}
		#elsif ($old_line =~ /^\'ftp:\/\/([^\/]*)(\/[^ ]*\/)([^ \/]+\.deb)\' ([^ ]*) ([^ ]*) ([^ ]*)/) {
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

sub validate_and_get_parameters(@) {
	
	my $i;
	
	if (scalar(@_) == 0) {
		return 0;
	}
	
	for($i=0;$i<scalar(@_);$i++) {
		debug_print("--->$_[$i]\n");
		if ($_[$i] =~ /-d|--debug/) {
			$deb_downloader_options{'debugger'} = YES;
		}
		elsif ($_[$i] =~ /--option=(.*)/) {
			if (lc($1) eq "build") {
				$deb_downloader_options{'option'} = BUILD_LIST;	
			}
			elsif (lc($1) eq "download") {
				$deb_downloader_options{'option'} = DOWNLOAD_PACKAGES;	
			}
			else {
				return 0;
			} 
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
		#$lines[$i] =~ /([^\/]*)(\/[^ ]*\/)([^ \/]+\.deb)\' ([^ ]*) ([^ ]*) ([^ ]*)/;
		if ($lines[$i] =~ /([^\/]*)(\/[^ ]*\/)([^ \/]+\.deb)\' ([^ ]*) ([^ ]*) ([^ ]*)/) {
			$deb_file = 1;
		}
		elsif($lines[$i] =~ /([^\/]*)(\/[^ ]*\/)([^ \/]+)\'/) {
			$deb_file = 0;
		}
		$target_directory = substr($2, 1, length($2)-1);
		if (! -d $pwd.$2) {
			print("Creating new directory $target_directory...");
			mkpath($target_directory) or die return 0;
			print("done\n");
		}
		print("Changing to $target_directory directory ...");
		chdir($target_directory);
		print("done\n");				
		if ($deb_file) {
			print("Downloading file $2$3 ($5 bytes)...");
			# print("Downloading file $2$3 (".human_printing($5).")...");
		}
		else {
			print("Downloading file $2$3...");
		}
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
	
	return 1;

}

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
		$target_directory = substr($2, 1, length($2)-1);
		if (! -d $pwd.$2) {
			print("Creating new directory $target_directory...");
			mkpath($target_directory) or die return 0;
			print("done\n");
		}
		print("Changing to $target_directory directory ...");
		chdir($target_directory);
		print("done\n");
		if ($deb_file) {
			print("Downloading file $2$3 ($5 bytes)...");
			# print("Downloading file $2$3 (".human_printing($5).")...");
		}
		else {
			print("Downloading file $2$3...");
		}
	    	$ftp_connection->cwd($2);
	    	@files = $ftp_connection->ls($3);
	    	debug_print("------------->" . scalar(@files) . "\n");
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
	
	$ftp_connection->quit;
    	
    	return 1;
    
}

###############################################################################
# Main body
###############################################################################

if (!validate_and_get_parameters(@ARGV)) {
	print("Error in parameters.\n");
	print_usage();
	exit 1;	
}

# Action to do.

if ($deb_downloader_options{'help'} eq YES) {
	print_usage();
}
if ($deb_downloader_options{'version'} eq YES) {
	print_version();
}
elsif ($deb_downloader_options{'option'} eq BUILD_LIST) {
	if (!build_list()) {
		print("\nPackages list built NOK :-(\n\n");
		print_usage();
		exit 1;					
	}
	print("\nPackages list built OK :-)\n\n");
}
elsif ($deb_downloader_options{'option'} eq DOWNLOAD_PACKAGES) {
	# Getting sources.list content
	#$sources_list_content = read_file($deb_downloader_options{'file'});
	$sources_list_content = read_sources($deb_downloader_options{'file'});
	debug_print("sources_list-->$sources_list_content\n");
	if (!$sources_list_content) {
		#print("Sources.list's file named $deb_downloader_options{'file'} not found.\n");
		print_usage();
		exit 1;		
	}
	
	# Parse sources.list getting the ftp and http server for downloading.
	if (!parse_sources_list()) {
		print("Error parsing sources.list.\n");
		print_usage();
		exit 1;		
	}	
	if (!download_packages()) {
		print("\nPackages downloaded NOK :-(\n\n");
		print_usage();
		exit 1;					
	}		
	print("\nPackages downloaded OK :-)\n\n");
}
else {
	print("\nOptions parameter erroneous.\n\n");
	print_usage();
	exit 1;				
}


exit 0;
