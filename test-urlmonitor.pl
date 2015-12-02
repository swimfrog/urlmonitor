#!/usr/bin/perl

# Please use an interpreted language to complete the question below,
# preferences in order of precedence are Python, Ruby and Perl.  A
# reasonable and well documented answer could take a few hours to
# produce.  Please stick to core language features (e.g. with the included
# batteries for Pythonistas).
#
# You are responsible for monitoring a web property for changes, the first
# proof of concept is a simple page monitor.  The requirements are:
# 1) Log to a file the changed/unchanged state of the URL
# http://www.oracle.com/index.html.
# 2) Retry a configurable number of times in case of connection oriented
# errors.
# 3) Handle URL content change or unavailability as a program error with a
# non-zero exit.
# 4) Any other design decisions are up to the implementer.  Bonus for
# solid design and extensibility.

=head1 NAME

test-urlmonitor.pl - Monitors an individual web page for changes

=head1 VERSION

Version 0.01

=cut

my $VERSION = 0.01;

=head1 SYNOPSIS

test-urlmonitor.pl [--help|h] [--man] [--version|V] [--verbose|v] <--url http://server.com/path/to/content> [--mode MODE] [--interval INT] [--retry TIMES] [--output FILE] [--timeout TIME]

=head1 OPTIONS

=over 4

=item B<--url URL>      Check this server URL for changes. This parameter is required.

=item B<--mode MODE>    Use the following method to detect changes:

=over 4

=item    B<content>    Use HTTP GET and monitor the content of the response.

=item    B<timestamp>  Use HTTP HEAD and monitor the timestamp of the response to detect changes.

=back

=item B<--interval INT> Wait this number of seconds between server checks. Default is 60.

=item B<--retry TIMES>  Retry failed connections up to this many times. Default is 3.

=item B<--output FILE>  Write status changes to FILE. By default, these messages are written to STDOUT unless an output file is specified.

=item B<--timeout TIME> Wait this many seconds for a response from the server before retrying. Default is 10 seconds.

=back

=cut

use Data::Dumper; #--Perl core
use Getopt::Long; #--Perl core
use Pod::Usage; #--Perl core
use LWP::UserAgent; #--Perl core
use Digest::MD5 qw (md5_hex); #--Perl core

my $mode = "timestamp";
my $retry = 3;
my $timeout = 10;
my $interval = 60;
our $verbose = 0;

# Bugs/Near-term improvements
#TODO: Replace STDOUT calls with variable output file handle
#TODO: Add handling for connecting to SSL server

# Future improvements:
#TODO: Add override for disabling following 302 redirects if the user doesn't want to follow redirects. LWP::UserAgent's default is to follow up to 7 hops.
#TODO: Future logic for retrieving page assets and detecting changes on them -- Allow it to work with things like rotating banners by caching and comparing only with previously-seen assets, etc.

Getopt::Long::Configure ("bundling");
GetOptions ('help' => sub { pod2usage(1); },
            'man' => sub { pod2usage(-exitstatus => 0, -verbose => 2); },
            'version|V' => sub { print "$0: version $VERSION\n"; exit 1; },
            'verbose|v+' => \$verbose,
            'mode=s' => \$mode,
            'retry=i' => \$retry,
            'outfile=s' => \$outfile,
            'timeout=i' => \$timeout,
            'interval=i' => \$interval,
            'url=s' => \$url,
) or pod2usage(2);

die("ERROR: You must specify --url") unless $url;
die("ERROR: Invalid --mode specified: $mode") unless ($mode =~ m/(?:content|timestamp)/);

our $retry_counter=0; #global variable to track the number of times we have iterated through the retry loop.

sub _handle_error {
   my $response = shift @_;

   # Allow the user to see the request and response data, if verbosity is high
   print STDERR "DEBUG: HTTP Request".Dumper($response->request->as_string) if ($verbose > 2);
   print STDERR "DEBUG: HTTP Response".Dumper($response->as_string) if ($verbose > 2);

   if ($response->is_error()) {
       print STDERR "WARNING: Retrieving content from server failed: ".$response->status_line."\n";

       $retry_counter++;

       if ($retry_counter == $retry) {
           # If we have reached the retry limit, then bomb out:
           die("ERROR: No successful response from server after $retry_counter tries.");
       }

       return;
   } else {
       print STDERR "INFO: Content md5sum is ".md5_hex($response->content)."\n" if $verbose;

       $retry_counter=0; #Reset the retry counter back to zero on success.
   }
}

# Instantiate the UserAgent
my $browser = LWP::UserAgent->new();
$browser->show_progress($verbose); # If verbose, show information about the request process.
$browser->timeout($timeout); # Pass in the timeout value from the arguments.

# Register a handler to check for errors and implement retry logic.
$browser->add_handler(
    response_done => \&_handle_error,
);

our $bucket=""; #Just some bits (used to store previously-seen values)
my $count=1;
while (true) {
   print STDOUT "INFO: Checking $url for changes (try #".$count.")\n" if $verbose;
   
   ## Some testing code to make sure the retry logic is sound
   #if (int(rand(2))) { # Fail 50 percent of the time (random 0 or 1 evaluates to true or false)
   #   #_handle_error(HTTP::Response->new(500, "erhmagherd", ["test", "test"], "")); # Test for retrying on timeout/server fail
   #} else {
   #   #_handle_error(HTTP::Response->new(0, "ok", ["test", "test"], "")); # Test for emulating a success.
   #}

   # Run the URL check, bouncing out to the error handler callback after each response (or timeout) is received, and potentially exiting based on a change on the server side, or a retry expiry.
   my $response;
   if ($mode eq "timestamp") {
      $response = $browser->head($url);

      # Assuming there was no error, look for changes, then fill the bucket with the new content data and rinse/repeat.
      my $lm = $response->header("Last-Modified");
      die("ERROR: timestamp mode was specified, but server did not return a \"Last-Modified\" HTTP header. You should use content mode with this URL instead.") unless $lm;
      
      print STDERR "INFO: established baseline timestamp as $lm\n" unless (($bucket) && ($verbose));

      if ($bucket ne $lm ) {
         die("WARNING: Server content has changed (was $bucket, now $lm)") if $bucket;
      }

      $bucket = $lm;

   } elsif ($mode eq "content") {
      $response = $browser->get($url);

      print STDERR "INFO: established baseline content as MD5: ".md5_hex($response->content)."\n" unless (($bucket) && ($verbose));

      if ($bucket ne $response->content ) {
         die("WARNING: Server content has changed (was ".md5_hex($bucket).", now ".md5_hex($response->content)) if $bucket;
      }

      $bucket = $response->content;
   }

   sleep $interval;
   $count++;
}

exit;
