package Test2::Harness::Renderer::TestingBufferedTeamCity;
use base qw( Test2::Harness::Renderer::BufferedTeamCity );

use strict;
use warnings;

use File::Basename qw(basename);
use TestSync qw( write_notification );

# the subroutine that listen returns is the main interface to the rest of
# Test2::Harness.  It's called once and should return a coderef that will be
# passed each job/event pair each time an event is posted
# We have to turn off perl critic here because Test2::Harness defines this
# interface, so we have to name our subroutine that
## no critic (ProhibitBuiltinHomonyms)
sub listen {
    my $self = shift;

    # get what the superclass is doing
    my $parent_anonymous_sub = $self->SUPER::listen;

    # augment it with an extra check.
    return sub {
        my $job   = shift;
        my $event = shift;

        return if $self->_handle_testing_events($event);

        $parent_anonymous_sub->( $job, $event );

        if ( $event->isa('Test2::Event::ProcessFinish') ) {
            my $name = basename( $job->file, '.st' );
            write_notification("$name-completed");
        }
    };
}
## use critic

# this is purely for the benefit of the test suite.  Test2::Harness doesn't
# magically process all the events the numerous test scripts that are running in
# exactly the order they're produced (since various processes are producing them
# and the OS decides which pipe sends data when), so if we want consistent order
# we need the test suite to not only sync themselves with the TestSync helper
# module from our test suite, we also need them to sync with the harness to
# pause until the harness has output the stuff we expected.  We do this by
# sending a custom event when we want to 'notify' and having the renderer
# in the controlling process actually write the 'notification' to disk
sub _handle_testing_events {
    my $self  = shift;
    my $event = shift;

    # Test2::Harness::Renderer::BufferedTeamCity::_debug('checking...');
    return unless $event->isa('Test2::Event::TeamCity::TestSyncEvent');

    # Test2::Harness::Renderer::BufferedTeamCity::_debug('..got a test sync event '.$event->name);

    write_notification( $event->name );
    return 1;
}

1;
