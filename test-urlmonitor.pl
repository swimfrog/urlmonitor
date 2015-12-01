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

test-urlmonitor.pl [--help|h] [--man] [--version|V] [--verbose|v] [--mode MODE] [--retry TIMES] [--timeout TIME] [--output FILE] 

=head1 OPTIONS

=over 4

=item B<--mode MODE>    Use the following method to detect changes:

=over 4

=item    B<content>    Use HTTP GET and monitor the content of the response.

=item    B<timestamp>  Use HTTP HEAD and monitor the timestamp of the response to detect changes.

=back

=item B<--retry TIMES>  Retry failed connections up to this many times. Default is 3.

=item B<--output FILE>  Write status changes to FILE. By default, these messages are written to STDOUT unless an output file is specified.

=item B<--timeout TIME> Wait this many seconds for a response from the server before retrying. Default is 10 seconds.

=back

=cut

my $mode = "timestamp";
my $retry = 3;
my $timeout = 10;

use Data::Dumper; #--Perl core
use Getopt::Long; #--Perl core
use Pod::Usage; #--Perl core

Getopt::Long::Configure ("bundling");
GetOptions ('help' => sub { pod2usage(1); },
            'man' => sub { pod2usage(-exitstatus => 0, -verbose => 2); },
            'version|V' => sub { print "$0: version $VERSION\n"; exit 1; },
            'verbose|v+' => \$verbose,
            'mode=s' => \$mode,
            'retry=i' => \$retry,
            'outfile=s' => \$outfile,
            'timeout=i' => \$timeout,
) or pod2usage(2);

exit;
