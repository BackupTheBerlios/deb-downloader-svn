use strict;

use Net::HTTP;
use Net::FTP;


###############################################################################
# Global variables.
###############################################################################

use constant BUILD_LIST => "build_list";
use constant DOWNLOAD_PACKAGES => "download_packages";
use constant VERSION => "0.1.0";

my $debugger_activated = 0;
my %deb_downloader_options = ("option"=>"", "sources_list"=>"");
			      
my $sources_list_content;
my @sources_list_content_lines = ();

###############################################################################
# Functions.
###############################################################################

sub print_usage() {
}

sub debug_print($) {
	
	if ($debugger_activated) {
		print(shift);
	}
	
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

sub build_list() {

	my $uris;
	my @uris_list;
	my $i;

	if (! -e '/usr/bin/apt-get') {
		print("apt-get is not installed in your system. Install it and repeat process execution\n");
		return 0;
	}

	if (length($deb_downloader_options{"sources_list"}) == 0) {
		print("sources file has not been provided.\n");
		return 0;
	}

	if (! -e $deb_downloader_options{'sources_list'}) {
		print("sources file $deb_downloader_options{'sources_list'} does not exist .\n");
		return 0;
	}
	
	if (!`apt-get update`) {
		print("Error executing apt-get update. Check it manually.\n");
		return 0;
	}
	
	$uris = `apt-get dist-upgrade --assume-yes --print-uris`;
	@uris_list = split(/\n+/, $uris);
	$uris = "";
	for($i=0;$i<scalar(@uris_list);$i++) {
		if ($uris_list[$i] =~ /^\'(?:http|ftp):\/\/[^\/]*\/[^ ]*\/[^ \/]+\.deb\' [^ ]* [^ ]* [^ ]*/) {
			$uris .= $uris_list[$i] . "\n";
		}
	}

	write_file($deb_downloader_options{'sources_list'}, $uris);
	return 1;
}

sub download_packages() {
	
	my $i;
	
	for($i=0;$i<scalar(@sources_list_content_lines);$i++) {
		debug_print("I am out of regex.\n");
		if ($sources_list_content_lines[$i] =~ /^\'(http|ftp):\/\/([^\/]*)(\/[^ ]*\/)([^ \/]+\.deb)\' ([^ ]*) ([^ ]*) ([^ ]*)/) {
			debug_print("I am in of regex.\n");
			debug_print("\$2-->$2\n");
			debug_print("\$3-->$3\n");
			debug_print("\$4-->$4\n");
			if ($1 eq "http") {
				#http_download("ftp.nl.debian.org", "/debian/pool/main/p/ppp/", "ppp_2.4.2+20040428-2_i386.deb");
				if (!http_download($2, $3, $4)) {
					print("not done\n");
					print("Error downloading file $sources_list_content_lines[$i] .\n");
					return 0;
				}
			}
			elsif ($1 eq "ftp") {
				#ftp_download("ftp.nl.debian.org", "/debian/pool/main/p/ppp/", "ppp_2.4.2+20040428-2_i386.deb");
				if (!ftp_download($2, $3, $4)) {
					print("not done\n");					
					print("Error downloading file $sources_list_content_lines[$i] .\n");
					return 0;
				}
			}
			else {
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
			$debugger_activated = 1;
		}
		elsif ($_[$i] =~ /--option=(.*)/) {
			if (lc($1) eq "build") {
				$deb_downloader_options{"option"} = BUILD_LIST;	
			}
			elsif (lc($1) eq "download") {
				$deb_downloader_options{"option"} = DOWNLOAD_PACKAGES;	
			}
			else {
				return 0;
			} 
		}		
		elsif ($_[$i] =~ /--sources_list=(.*)/) {
			$deb_downloader_options{"sources_list"} = $1;	
		}
		else {
			return 0;
		}
	}
	
	return 1;	
	
}

sub parse_sources_list(){
	
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
	
	return 1;
	
}

sub http_download(@) {
	
	my $host_name;
	my $host_path;
	my $host_file;
	my $http_connection;
	my $code;
	my $mess;
	my %h;
	my $internal_buffer;
	
	if (scalar(@_) != 3) {
		return 0;
	}
	
	$host_name = shift;
	$host_path = shift;
	$host_file = shift;
	
	debug_print("\http$host_name-->$host_name\n");	
	debug_print("\http$host_path-->$host_path\n");	
	debug_print("\http$host_file-->$host_file\n");		

	print("Downloading file $host_file...");

	$http_connection = Net::HTTP->new(Host => $host_name) || die "Error openning ftp.nl.debian.org http http_connection\n";
	$http_connection->write_request(GET => $host_path.$host_file, 'User-Agent' => "Mozilla/5.0");
	($code, $mess, %h) = $http_connection->read_response_headers;
	
	open(DEBFILE,">$host_file") or die "Error opening output file $host_file.\n";
	binmode(DEBFILE);
	
	while ($http_connection->read_entity_body($internal_buffer, 1024) > 0) {
		print DEBFILE $internal_buffer;
	}
	
	close(DEBFILE);	
	
	print("done\n");

	return 1;

}

sub ftp_download(@) {
	
	my $ftp_connection;
	my $host_name;
	my $host_path;
	my $host_file;
	
	if (scalar(@_) != 3) {
		return 0;
	}
	
	$host_name = shift;
	$host_path = shift;
	$host_file = shift;	
	
	debug_print("ftp\$host_name-->$host_name\n");	
	debug_print("ftp\$host_path-->$host_path\n");	
	debug_print("ftp\$host_file-->$host_file\n");	
	
	print("Downloading file $host_file...");
	
    	$ftp_connection = Net::FTP->new($host_name, Debug => 0)  || die "Error openning ftp.nl.debian.org ftp http_connection\n";
    	$ftp_connection->login("anonymous",'-anonymous@');
    	$ftp_connection->binary();
    	$ftp_connection->cwd($host_path);
    	$ftp_connection->get($host_file);
    	$ftp_connection->quit;
    	
	print("done\n");    	
    	
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

# Getting sources.list content
$sources_list_content = read_file($deb_downloader_options{"sources_list"});
debug_print("sources_list-->$sources_list_content\n");
if (!$sources_list_content) {
	print("Sources_list's file named $deb_downloader_options{'sources_list'} not found.\n");
	print_usage();
	exit 1;		
}

# Parse sources.list getting the ftp and http server for downloading.
if (!parse_sources_list()) {
	print("Error parsing sources.list.\n");
	print_usage();
	exit 1;		
}

# Action to do.
if ($deb_downloader_options{"option"} eq BUILD_LIST) {
		if (!build_list()) {
			print("\nPackages list built NOK :-(\n\n");
			print_usage();
			exit 1;					
		}
		print("\nPackages list built OK :-)\n\n");
}
elsif ($deb_downloader_options{"option"} eq DOWNLOAD_PACKAGES) {
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
