#!/usr/bin/perl

=head1 NAME

urlmonitor.pl - Monitors an individual web page for changes

=head1 VERSION

Version 0.01

=cut

my $VERSION = 0.01;

=head1 SYNOPSIS

urlmonitor.pl [--help|h] [--man] [--version|V] [--verbose|v] <--url http://server.com/path/to/content> [--mode MODE] [--interval INT] [--retry TIMES] [--output FILE] [--timeout TIME]

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

=item B<--verbose|v>    -v - show INFO-level detail, -vv show DEBUG-level detail, -vvv shows TRACE-level detail (log of HTTP request/response). Default shows only warnings and fatal errors. This will also determine the level of detail logged to --outfile, if that option is specified.

=back

=cut

use Data::Dumper; #--Perl core
use Getopt::Long; #--Perl core
use Pod::Usage; #--Perl core
use LWP::UserAgent; #--Perl core
use Digest::MD5 qw (md5_hex); #--Perl core
use POSIX qw(strftime); #--Perl core

my $mode = "timestamp";
my $retry = 3;
my $timeout = 10;
my $interval = 60;
our $verbose = 0;
my $outfile = "/dev/stdout";

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

# Create/append an output file handle (or copy stdin)
open(my $outfh, '>>', $outfile) or die("ERROR: Could not open logfile $outfile: $!");

sub _log {
   # Crappy logging function to avoid having to use a non-core logging module for my simple use case. Adds a timestamp, and if the severity is "fatal", causes the program to die (exit with returncode 255)

   my $severity = shift @_;
   my $message = shift @_;

   my $ts = strftime '%Y-%m-%d %H:%M:%S ', gmtime();
   print $outfh $ts.uc($severity).": $message\n";

   if ($severity eq "fatal") {
      die(uc($severity).": $message");
   }
}

sub _handle_error {
   # Subroutine that acts as a handler for LWP::UserAgent, implementing retry logic, outputting info-level detail when content is retrieved, and allowing the user to easily enable trace mode to see HTTP request/response data.

   my $response = shift @_;

   # Allow the user to see the request and response data, if verbosity is high
   _log("trace", "HTTP Request: ".$response->request->as_string) if ($verbose > 2);
   _log("trace", "HTTP Response: ".$response->as_string) if ($verbose > 2);

   if ($response->is_error()) {
       _log("warning", "Retrieving content from server failed: ".$response->status_line);

       $retry_counter++;

       if ($retry_counter == $retry) {
           # If we have reached the retry limit, then bomb out:
           _log("fatal", "No successful response from server after $retry_counter tries.");
       }

       return;
   } else {
       unless($response->is_redirect) {
          _log("info", "Content md5sum is ".md5_hex($response->content)) if $verbose;

          $retry_counter=0; #Reset the retry counter back to zero on success.
       }
   }
}

# Instantiate the UserAgent
my $browser = LWP::UserAgent->new();
$browser->show_progress($verbose > 1 ? 1 : 0); # If verbose >=2, output information about the request process to STDERR.
$browser->timeout($timeout); # Pass in the timeout value from the arguments.

# Register a handler to check for errors and implement retry logic.
$browser->add_handler(
    response_done => \&_handle_error,
);

our $bucket=""; #Just some bits (used to store previously-seen values)
my $count=1;
while (true) {
   _log("info", "Checking $url for changes (#".$count.")") if $verbose;
   
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

      # As long as there was no error, look for changes, then fill the bucket with the new content data and rinse/repeat.
      unless ($response->is_error()) {
         my $lm = $response->header("Last-Modified");
         _log("fatal", "timestamp mode was specified, but server did not return a \"Last-Modified\" HTTP header. You should use content mode with this URL instead.") unless $lm;
         
         _log("info", "established baseline timestamp as $lm") if ((! $bucket) && ($verbose));
   
         if ($bucket ne $lm ) {
            _log("fatal", "Server content has changed (was $bucket, now $lm)") if $bucket;
         }
   
         $bucket = $lm;
      }

   } elsif ($mode eq "content") {
      $response = $browser->get($url);

      unless ($response->is_error()) {
         print $outfh "INFO: established baseline content as MD5: ".md5_hex($response->content)."\n" if ((! $bucket) && ($verbose));
   
         if ($bucket ne $response->content ) {
            _log("fatal", "Server content has changed (was ".md5_hex($bucket).", now ".md5_hex($response->content)) if $bucket;
         }
   
         $bucket = $response->content;
      }
   }

   sleep $interval;
   $count++;
}

exit;
