#!/usr/bin/perl
#
# Webhook Handler
#

#
# Set HTTP_ACTION to action name for dispatch
# Set HTTP_DEBUG if logging to api/Log is required
# Set HTTP_ACCESSKEY to match apikey in Handler
#

use strict;
use warnings;

print "Content-type: text/json\n\n" ;

my $jsontxt = "";
my $response = "" ;
my $action = "" ;

eval {

	use 5.010;
	use JSON ;
	use CGI ;

	use File::Basename;
	use Cwd qw(abs_path);

	use lib dirname ( abs_path(__FILE__) ) ;
	use Lib::Conversation;
	
########################
# Load JSON Query

	my $argc = @ARGV ;

	if ( $argc==0 ) {

		# Receive Posted Data

		my $q = CGI->new;
		$jsontxt = $q->param( 'POSTDATA' );

	} else {

		# Load Data from File

		open(my $fh, '<:encoding(UTF-8)', $ARGV[0]) 
		or die "Unable to load data from '$ARGV[0]'" ;

		while (my $line = <$fh>) {
			chomp $line ;
			$jsontxt = $jsontxt . $line . "\n";
		}
		close $fh;

	}


########################
# Process the request

	if ( ! $jsontxt ) {
		die "No JSON Request Detected" ;
	}

	my $conv = Conversation->new($jsontxt) ;

########################
# Dispatch to Handler

	$action = $ENV{"HTTP_ACTION"} ;

	die "Action not defined. Ensure there is a header with key 'action' and a value that matches the subdirectory in Actions." if !$action ;

	my $handler = dirname ( abs_path(__FILE__) ) . "/Actions/$action/Handler.pm" ;

	eval {
		require "$handler" ;
		1;
	} or do {
		die "Error loading Actions/$action/Handler.pm~#~$@" ;
	} ;
	
	Handler::process($conv) ;
	$response = $conv->response() ;	

	
########################
# Output Response

	print "$response\n" ;
		
  
} or do {
	
    my ($err) = $@;
    my $error ="" ;
    my $message ="" ;
    my $file ="" ;
    my $line ="" ;

	$err =~ s/"/\\"/g ;
    $err =~ s/\n/\\n/g ;
    $err =~ s/\\n$/\n/g ;
    
	# error message~#~error details at ./filepath line num, more details
	($error, $message, $file, $line) = ( $err =~ /^([^\.]*)~#~(.*) at ([w\.\/].*) line (\d*), .*$/ ) ;

	if (!$line) {
		# error message~#~error details at ./filepath line num.
		($error, $message, $file, $line) = ( $err =~ /^([^\.]*)~#~(.*) at ([w\.\/].*) line (\d*).$/ ) ;
	}
	
	if (!$line) {
		# error message at ./filepath line num, more details
		($message, $file, $line) = ( $err =~ /^(.*) at ([w\.\/].*) line (\d*), .*$/ ) ;
		$error = "Internal Fault Detected" ;
	}
	
	if (!$line) {
		# error message at ./filepath line num.
		($message, $file, $line) = ( $err =~ /^(.*) at ([w\.\/].*) line (\d*).$/ ) ;
		$error = "Internal Fault Detected" ;
	}
	if (!$line) {
		$message="unknown" ;
		$file="unknown" ;
		$line="unknown" ;
		$error="Internal Fault Detected" ;
	}
	if ( "$error" eq "NOKEY" ) {
		$error = "Invalid API Key Provided" ;
		$message = "Check Key in calling script or accesskey in dialogflow fulfilment" ;
		$file = "undisclosed" ;
		$line = "undisclosed" ;
		$err = "NOKEY" ;
	}
	
	print "{\n  \"error\": \"$error\",\n  \"overview\": \"$message\",\n  \"file\": \"$file\",\n  \"line\": \"$line\",\n  \"details\": \"$err\"\n}\n" ;
	
};

########################
# Log Query and Response

if ( $ENV{'HTTP_DEBUG'} ) {

if (!$action) {	$action="unknown" ; }

my $logfile = dirname ( abs_path(__FILE__) ) . "/Log/" . $action . "-"  ;

open(my $frq, '>:encoding(UTF-8)', $logfile . "request.json" ) 
or die "Unable write to '" . $logfile . "-request.json'" ;
print $frq gmtime() . ":\n" ;
print $frq $jsontxt ;
close $frq ;

open(my $frs, '>:encoding(UTF-8)', $logfile . "response.json" ) 
or die "Unable write to '" . $logfile . "-response.json'" ;
print $frs gmtime() . ":\n" ;
print $frs $response ;
close $frs ;

open(my $fe, '>:encoding(UTF-8)', $logfile . "environment.json" ) 
or die "Unable write to '" . $logfile . "-environment.json'" ;
print $fe gmtime() . ":\n" ;
foreach my $key (sort keys(%ENV)) {
	print $fe "$key = $ENV{$key}\n";
}	
close $fe ;

use POSIX qw(strftime);

my $time = gmtime ;
my $dates = strftime "%Y%m%d%H%M%S", gmtime ;

open(my $fa, '>:encoding(UTF-8)', $logfile . $dates . ".json" ) 
or die "Unable write to '" . $logfile . $dates . ".json'" ;
print $fa $time . ":\n" ;
print $fa "===================================================\n" ;
print $fa "REQUEST\n" ;
print $fa "$jsontxt\n" ;
print $fa "===================================================\n" ;
print $fa "RESPONSE\n" ;
print $fa "$response\n" ;

close $fa ;

}
