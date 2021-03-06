###############################################################################
#
# deb_downloader 06-08-2004 
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
# 	18-10-2004 - deb_downloader version 0.1.15.
#
#
###############################################################################

###############################################################################
#
# Notes : 
# 
# - Pendent mirar que passa amb la connexi� del HTTP (s'ha d'obrir cada vegada).
# - Control�lar l'existencia de l'arxiu al servidor per transfer�ncies http.
# - Donar la possibilitat d'executar en dos modes (format mirror(amb directoris
#   i tota la pesca) i sense format(tot al mateix directory)).
# - Passar la sortida de l'execuci� de apt-get dist-upgrade a  un pipe sense 
#   la necessitat de crear un arxiu.
# - Pulir les expresions regulars usades (fer-les m�s estrictes).
# - Informar del directori de destinaci� de la copia dels arxius (per defecte
#   /var/cache/apt/archives/ (implementar el parametre).
# - Comprovar abans de fer el download que l'arxiu no existeix, si existeix
#   passar al seg�ent (suposant que si existeix es el mateix).
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

use constant NAME => "deb-downloader";
use constant MAIL => "ktala\@badopi.org";
use constant VERSION => "0.1.15";
use constant BUILD_LIST => "build_list";
use constant DOWNLOAD_PACKAGES => "download_packages";
use constant INSTALL_PACKAGES => "install_packages";
use constant YES => "Y";
use constant NO=> "N";
use constant DEFAULT_OUTPUT_DIRECTORY => '/var/cache/apt/archives/';

my %deb_downloader_options = (	
				"debugger"=>"N",
   				"option"=>"", 
				"file"=>"sources.list", 
				"skip-update"=>"N", 
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

sub print_version() {

	print("\n");
	print(NAME . " " . VERSION . " Copyright (C) 2004 Miquel Oliete <" . MAIL . ">\n");
	print("\n");
	print("This program is free software; you can redistribute it and/or modify\n");
	print("it under the terms of the GNU General Public License as published by\n");
	print("the Free Software Foundation; version 2 of the License.\n");
	print("\n");

}

sub print_usage() {

	print_version();
	print("\n");
	print("Usage : \n");
	print("\n");
	print("  " . NAME . " --help | --version | --option=build|download|install [--dd-root=directory] --file=filename [--skip-update] [--mirror-format] [--execute-dist-upgrade]  [-d|--debug]  \n");
	print("\n");
	
}

sub debug_print($) {
	
	if ($deb_downloader_options{'debugger'} eq YES) {
		print(shift);
	}
	
}

sub deb_downloader_exit($) {

	my $exit_code;

	$exit_code = shift;
	cwd($execution_directory);
	if ($exit_code != 0) {
		print_usage();
	}
	exit($exit_code);
}

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

sub validationsOK($) {

	my $option = shift;


	if (length($deb_downloader_options{'file'}) == 0) {
    		print("sources file has not been provided.\n");
		return 0;
	}
	

	if ($option eq BUILD_LIST) {
		return build_validations();
	}

	if ($option eq INSTALL_PACKAGES) {
		return install_validations();
	}

	if ($option eq DOWNLOAD_PACKAGES) {
		return download_validations();
	}
	
	return 1;

}

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

sub build_validations() {

	my $user;

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

sub download_validations() {

	if (length($deb_downloader_options{'dd-root'}) == 0) {
		print("root directory has not been filled.\n");
		return 0;
	}
					 
	return 1;

}

sub install_validations() {

	my $user;

	if (!is_debian_ready()) {
		return 0;
	}

	if ($deb_downloader_options{'execute-dist-upgrade'} eq YES) {
		$user = `whoami`;
	   	debug_print("------>" . $user . "\n");
		chomp($user);
		if ($user ne 'root') {
			print("This script option has to be executed as a root user.\n");
	        return 0;
	    }
	}
	
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

	if (! are_all_needed_files_downloaded($deb_downloader_options{'dd-root'})) {
   	   print("There is/are needed file(s) which is/are not downloaded. Please run build and download options.\n");
	   return 0;
	}

	return 1;

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

	my $uris;
	my @uris_list;
	my $i;
	my $question;


	if (!validationsOK(BUILD_LIST)) {
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

sub download_packages() {
	
	my $i;
	my $j;
	my $pwd;
	my $old_line;
	my @file_lines;

	$|=1;


    if (!validationsOK(DOWNLOAD_PACKAGES)) {
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
	
	$ftp_connection->quit;
    	
    	return 1;
    
}

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
	       		print("Copying file $target_directory$pathname$filename...");
				copy("$deb_downloader_options{'dd-root'}$pathname$filename", "$target_directory$filename");
				print("done\n");
			}
		}
	}

	close(SOURCE_DIR);
	
	return 1;
}


sub install_packages {

	my $user;
	my $files_copied_ok;

    if (!validationsOK(INSTALL_PACKAGES)) {
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
		elsif ($_[$i] =~ /--option=(.*)/) {
			if (lc($1) eq "build") {
				$deb_downloader_options{'option'} = BUILD_LIST;	
			}
			elsif (lc($1) eq "download") {
				$deb_downloader_options{'option'} = DOWNLOAD_PACKAGES;	
			}
			elsif (lc($1) eq "install") {
				$deb_downloader_options{'option'} = INSTALL_PACKAGES;	
			}
			else {
				return 0;
			} 
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
		elsif ($_[$i] eq "--skip-update") {
			$deb_downloader_options{'skip-update'} = YES;
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
elsif ($deb_downloader_options{'option'} eq BUILD_LIST) {
	if (!build_list()) {
		print("\nPackages list built NOK :-(\n\n");
		deb_downloader_exit(1);
	}
	print("\nPackages list built OK :-)\n\n");
}
elsif ($deb_downloader_options{'option'} eq DOWNLOAD_PACKAGES) {
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
elsif ($deb_downloader_options{'option'} eq INSTALL_PACKAGES) {
	if (!install_packages()) {
		print("\nPackages installed NOK :-(\n\n");
		deb_downloader_exit(1);		
	}		
	print("\nPackages installed OK :-)\n\n");
}
else {
	print("\nOptions parameter erroneous.\n\n");
	deb_downloader_exit(1);
}


deb_downloader_exit(0);
