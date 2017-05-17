package TestSync;

# this class is a really dumb inter-process notification.  It uses a common
# temp dir (that should be set in the TESTSYNC_TEMPDIR env var) to communicate.
# It works simply by polling for the existence of the named file in that dir

use strict;
use warnings;
use autodie;

use File::Temp qw( tempdir );
use File::Spec::Functions qw( catfile );
use Test2::API qw( context );
use Test2::Bundle::Extended;
use Test2::Event::TeamCity::TestSyncEvent;
use Time::HiRes qw( usleep );

use Exporter qw( import );

our @EXPORT_OK = qw(
    send_notification
    wait_for_events_to_be_processed
    wait_for_notification
    write_notification
);

# use two variables here to avoid combining magic of %ENV with magic of
# something that cleans up after itself
my $tempdir = $ENV{TESTSYNC_TEMPDIR};
unless ($tempdir) {
    $tempdir = tempdir( CLEANUP => 1 );
    ## no critic (Variables::RequireLocalizedPunctuationVars)
    $ENV{TESTSYNC_TEMPDIR} = $tempdir;
    ## use critic
}

sub DEBUG { $ENV{TEST2_TEAMCITY_VERBOSE} }

# we write to a known temp file if DEBUG is turned on.  We can't
# print out in the normal way without that getting horribly lost
sub _debug {
    return unless DEBUG();
    open my $fh, '>>', '/tmp/stuff.txt';
    print $fh "$_\n" for @_;
    close $fh;
}

sub _filename_for_notification {
    my $name = shift;
    _debug("tempdir is $tempdir\n");
    return catfile( $tempdir, $name );
}

sub wait_for_notification {
    my $name     = shift;
    my $filename = _filename_for_notification($name);

    _debug("$0: waiting for $name");
    my $counter = 0;
    do {
        $counter++;
        usleep(100);

        if ( $counter >= 20 ) {
            $counter = 0;
            _debug("$0: still waiting for $name");
        }
    } while !-e $filename;
    _debug( $0 . ': received ' . $name );

    return;
}

# sending for notification doesn't actually write the notification file -
# it sends a Test2::Event::TeamCity::TestSyncEvent and then the code in
# Test2::Harness::Renderer::TestingBufferedTeamCity calls write_notification
# when it receives that event - this ensures that not only has the notification
# been sent by the process, it also ensures that everything that process has
# created up to that point has actually been processed
sub send_notification {
    my $name     = shift;
    my $filename = _filename_for_notification($name);

    _debug( $0 . ': sending ' . $name );

    # send the event that (eventually) will result in the file being
    # written to disk in the harness renderer when this is received
    {
        my $ctx = context();
        $ctx->send_event( 'TeamCity::TestSyncEvent', name => $name );
        $ctx->release;    # Release the context
    }

    # wait for the event to have round tripped via the harness renderer
    # and the notification to have been written to disk before continuing
    wait_for_notification($name);

    return;
}

# used in Test2::Harness::Renderer::TestingBufferedTeamCity when it sees the
# TeamCity::TestSyncEvent notification event.
sub write_notification {
    my $name     = shift;
    my $filename = _filename_for_notification($name);

    open my $fh, '>', $filename
        or die "Can't open for writing '$filename': $!";
    print $fh "1\n"
        or die "Can't print to '$filename': $!";
    close $fh
        or die "Can't close '$filename': $!";
}

# this is used to make sure that any events we've sent have been processed
# by the harness.  It's just an notification with a random name that no-one
# other than ourselves is listening for, and once that's round tripped, all
# events will have been processed
my $counter = 0;

sub wait_for_events_to_be_processed {
    $counter++;
    send_notification( 'sync' . $counter );
}

1;
