# Purpose #

For a coding exercise:

Please use an interpreted language to complete the question below, preferences in order of precedence are Python, Ruby and Perl.  A reasonable and well documented answer could take a few hours to produce. Please stick to core language features (e.g. with the included batteries for Pythonistas).

You are responsible for monitoring a web property for changes, the first proof of concept is a simple page monitor. The requirements are:

1. Log to a file the changed/unchanged state of the URL http://www.oracle.com/index.html.
1. Retry a configurable number of times in case of connection oriented errors.
1. Handle URL content change or unavailability as a program error with a non-zero exit.
1. Any other design decisions are up to the implementer.  Bonus for solid design and extensibility.

# Approach #

I decided to use Perl for this, simply because that is what I could do most quickly. If there had been any additional requirements, such as integration with a larger suite of tools, I probably would have chosen Python with urllib2, argparse, etc. The implementation of retries, content checking, and argument handling would not have been substantially different. Most people find Perl's POD off-putting (and so do I), but it can do some magical things, like making --help and the --man options work with minimal duplication of code, so for a quick-and-dirty CLI interface, GetOpt::Long and pod2usage are kind of a swiss army knife for me. You just have to overlook the ugliness of the markup ;)

As I was thinking about how to tackle the problem, I decided to take the approach of supporting two polling modes: one whereby the content is simply downloaded and compared, and another where an HTTP HEAD request was issued, and the "Last-Modified" header was compared between runs. The thinking here was that for a simple index.html check, content mode is fine (i.e. not expensive), but if you want to start monitoring large binary objects or something, a lighter touch might be needed. Not every server/URI sends the Last-Modified response header though, so there is a warning message to the user when this is the case.

Some niceties of LWP are leveraged here, making HTTP request/response tracing (with -vvv) and HTTP progress indicators (with -vv) nearly free.

# Usage #

    urlmonitor.pl [--help|h] [--man] [--version|V] [--verbose|v] --url http://server.com/path/to/content [--mode MODE] [--interval INT] [--retry TIMES] [--output FILE] [--timeout TIME]

#### OPTIONS ####
       --url URL      Check this server URL for changes. This parameter is required.
       --mode MODE    Use the following method to detect changes:
           content    Use HTTP GET and monitor the content of the response.
           timestamp  Use HTTP HEAD and monitor the timestamp of the response to detect changes.
       --interval INT Wait this number of seconds between server checks. Default is 60.
       --retry TIMES  Retry failed connections up to this many times. Default is 3.
       --output FILE  Write status changes to FILE. By default, these messages are written
                      to STDOUT unless an output file is specified.
       --timeout TIME Wait this many seconds for a response from the server before retrying.
                      Default is 10 seconds.
       --verbose|v    -v - show INFO-level detail, -vv show DEBUG-level detail, -vvv shows
                      TRACE-level detail (log of HTTP request/response). Default shows only
                      warnings and fatal errors. This will also determine the level of detail
                      logged to --outfile, if that option is specified.

# Examples #

##### To monitor a page using "timestamp" mode: #####
    $ ./urlmonitor.pl -v --interval 1 --retry 2 --url http://www.swimfrog.com/index.html
    2015-12-02 04:18:48 INFO: Checking http://www.swimfrog.com/index.html for changes (#1)
    2015-12-02 04:18:48 INFO: Content md5sum is d41d8cd98f00b204e9800998ecf8427e
    2015-12-02 04:18:48 INFO: established baseline timestamp as Wed, 02 Dec 2015 04:18:45 GMT
    2015-12-02 04:18:49 INFO: Checking http://www.swimfrog.com/index.html for changes (#2)
    2015-12-02 04:18:49 INFO: Content md5sum is d41d8cd98f00b204e9800998ecf8427e
    2015-12-02 04:18:50 INFO: Checking http://www.swimfrog.com/index.html for changes (#3)
    2015-12-02 04:18:50 INFO: Content md5sum is d41d8cd98f00b204e9800998ecf8427e
    2015-12-02 04:18:51 INFO: Checking http://www.swimfrog.com/index.html for changes (#4)
    2015-12-02 04:18:51 INFO: Content md5sum is d41d8cd98f00b204e9800998ecf8427e
    2015-12-02 04:18:52 INFO: Checking http://www.swimfrog.com/index.html for changes (#5)
    2015-12-02 04:18:52 INFO: Content md5sum is d41d8cd98f00b204e9800998ecf8427e
    2015-12-02 04:18:52 FATAL: Server content has changed (was Wed, 02 Dec 2015 04:18:45 GMT, now Wed, 02 Dec 2015 04:18:51 GMT)
    FATAL: Server content has changed (was Wed, 02 Dec 2015 04:18:45 GMT, now Wed, 02 Dec 2015 04:18:51 GMT) at ./urlmonitor.pl line 94.

##### To monitor a page in "content" mode: #####
    $ ./urlmonitor.pl -v --mode=content --interval 1 --retry 2 --url http://www.oracle.com/index.html
    2015-12-02 04:20:51 INFO: Checking http://www.oracle.com/index.html for changes (#1)
    2015-12-02 04:20:51 INFO: Content md5sum is 68eaa3d843e512b79f88691c87692b34
    INFO: established baseline content as MD5: 68eaa3d843e512b79f88691c87692b34
    2015-12-02 04:20:52 INFO: Checking http://www.oracle.com/index.html for changes (#2)
    2015-12-02 04:20:52 INFO: Content md5sum is 68eaa3d843e512b79f88691c87692b34
    2015-12-02 04:20:53 INFO: Checking http://www.oracle.com/index.html for changes (#3)
    2015-12-02 04:20:53 INFO: Content md5sum is 68eaa3d843e512b79f88691c87692b34
    2015-12-02 04:20:54 INFO: Checking http://www.oracle.com/index.html for changes (#4)
    2015-12-02 04:20:54 INFO: Content md5sum is 0a7ceb3e46120c202e55edb02fd151d4
    2015-12-02 04:20:54 FATAL: Server content has changed (was 68eaa3d843e512b79f88691c87692b34, now 0a7ceb3e46120c202e55edb02fd151d4
    FATAL: Server content has changed (was 68eaa3d843e512b79f88691c87692b34, now 0a7ceb3e46120c202e55edb02fd151d4 at ./urlmonitor.pl line 94.
    
##### If an error occurs, the program will try up to --retry consecutive tries to retrieve the content before giving up: #####

    $ ./urlmonitor.pl -v --mode=content --interval 1 --retry 5 --url http://www.swimfrog.com/index.html
    2015-12-02 04:27:29 INFO: Checking http://www.swimfrog.com/index.html for changes (#1)
    2015-12-02 04:27:30 INFO: Content md5sum is fc14d5a30af5c76a846749dcab786b13
    INFO: established baseline content as MD5: fc14d5a30af5c76a846749dcab786b13
    2015-12-02 04:27:31 INFO: Checking http://www.swimfrog.com/index.html for changes (#2)
    2015-12-02 04:27:31 INFO: Content md5sum is fc14d5a30af5c76a846749dcab786b13
    2015-12-02 04:27:32 INFO: Checking http://www.swimfrog.com/index.html for changes (#3)
    2015-12-02 04:27:32 INFO: Content md5sum is fc14d5a30af5c76a846749dcab786b13
    2015-12-02 04:27:33 INFO: Checking http://www.swimfrog.com/index.html for changes (#4)
    2015-12-02 04:27:33 INFO: Content md5sum is fc14d5a30af5c76a846749dcab786b13
    2015-12-02 04:27:34 INFO: Checking http://www.swimfrog.com/index.html for changes (#5)
    2015-12-02 04:27:34 WARNING: Retrieving content from server failed: 500 Can't connect to www.swimfrog.com:80 (Connection refused)
    2015-12-02 04:27:35 INFO: Checking http://www.swimfrog.com/index.html for changes (#6)
    2015-12-02 04:27:35 WARNING: Retrieving content from server failed: 500 Can't connect to www.swimfrog.com:80 (Connection refused)
    2015-12-02 04:27:36 INFO: Checking http://www.swimfrog.com/index.html for changes (#7)
    2015-12-02 04:27:37 INFO: Content md5sum is fc14d5a30af5c76a846749dcab786b13
    2015-12-02 04:27:38 INFO: Checking http://www.swimfrog.com/index.html for changes (#8)
    2015-12-02 04:27:38 INFO: Content md5sum is fc14d5a30af5c76a846749dcab786b13
    2015-12-02 04:27:39 INFO: Checking http://www.swimfrog.com/index.html for changes (#9)
    2015-12-02 04:27:39 INFO: Content md5sum is fc14d5a30af5c76a846749dcab786b13
    2015-12-02 04:27:40 INFO: Checking http://www.swimfrog.com/index.html for changes (#10)
    2015-12-02 04:27:40 WARNING: Retrieving content from server failed: 500 Can't connect to www.swimfrog.com:80 (Connection refused)
    2015-12-02 04:27:41 INFO: Checking http://www.swimfrog.com/index.html for changes (#11)
    2015-12-02 04:27:41 WARNING: Retrieving content from server failed: 500 Can't connect to www.swimfrog.com:80 (Connection refused)
    2015-12-02 04:27:42 INFO: Checking http://www.swimfrog.com/index.html for changes (#12)
    2015-12-02 04:27:42 WARNING: Retrieving content from server failed: 500 Can't connect to www.swimfrog.com:80 (Connection refused)
    2015-12-02 04:27:43 INFO: Checking http://www.swimfrog.com/index.html for changes (#13)
    2015-12-02 04:27:43 WARNING: Retrieving content from server failed: 500 Can't connect to www.swimfrog.com:80 (Connection refused)
    2015-12-02 04:27:44 INFO: Checking http://www.swimfrog.com/index.html for changes (#14)
    2015-12-02 04:27:44 WARNING: Retrieving content from server failed: 500 Can't connect to www.swimfrog.com:80 (Connection refused)
    2015-12-02 04:27:44 FATAL: No successful response from server after 5 tries.
    FATAL: No successful response from server after 5 tries. at ./urlmonitor.pl line 94.


# Limitations / Future improvements #

* There are very few HTTP and SSL-specific options implemented here. Real use cases may call for overriding the User-Agent, injecting HTTP headers, or overriding SSL certificate verification options.

* Only GET and HEAD are supported as retrieval options. Monitoring using POST method isn't implemented, but would be fairly easy to add, with a little argument wiring.

* Two runs worth of actual content are stored in memory for comparison when using "content" mode. Given very large inputs, memory constraints and the overhead of calculating MD5 will become prohibitive.

* It is not currently possible to display a different level of verbosity to the terminal while logging to a file. If you want that, pipe through tee instead of using --outfile.

* Currently, this will follow 302 redirects, but the user might not necessarily want that behavior. LWP::UserAgent's default is to follow up to 7 hops. Allowing this to be disabled would be pretty trivial (set max hops to 0).

* Some logic for retrieving page assets and detecting changes on them might be in order to improve this for more complex site monitoring. HTML::TreeBuilder could be used to extract assets for retrieval.
  * Allow it to work with things like rotating banners by caching and comparing assets only with previously-seen content, etc.
