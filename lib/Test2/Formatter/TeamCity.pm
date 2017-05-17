package Test2::Formatter::TeamCity;

use strict;
use warnings;

use parent 'Test2::Formatter';

use TeamCity::Message qw( tc_message tc_timestamp );
## no critic (BuiltinFunctions::ProhibitStringyEval)
BEGIN { eval 'use Win32::Console::ANSI; 1' or die $@ if 'MSWin32' eq $^O; }
## use critic
use Term::ANSIColor qw( color );
use Test2 1.0203060 ();
use Test2::Formatter::TeamCity::Suite;

our $VERSION = '1.000000';

# The no_* attributes are solely there so Test::Builder doesn't complain. What
# they're set to has no impact on the output from this Formatter class.
use Test2::Util::HashBase
    qw( no_diag no_header no_numbers _handle _current _finalized _top );

sub init {
    my $self = shift;

    # TODO: BUG BUG BUG BUG
    # This shouldn't dup STDOUT, but use Test2::API's test2_stdout function to
    # get the original STDOUT instead *but* that hasn't been released to the
    # CPAN at the time I'm coding this, so, c'est la vie.
    ## no critic (InputOutput::RequireBriefOpen)
    open my $fh, '>&', STDOUT or die "Can't dup STDOUT: $!";
    ## use critic

    $fh->autoflush(1);
    $self->{ +_HANDLE } = $fh;

    $self->_start_suite( $0, 0, $0 );

    return;
}

sub hide_buffered {1}

sub encoding {
    my $self     = shift;
    my $encoding = shift;

    binmode $self->{ +_HANDLE }, $encoding
        or die $!;

    return;
}

sub DEBUG { $ENV{TEST2_TEAMCITY_VERBOSE} }

sub _debug {
    return unless DEBUG();
    print STDERR color('yellow'), @_, "\n", color('reset')
        or die "Can't print to STDERR?: $!";
    return;
}

sub _debug_event {
    my $self  = shift;
    my $event = shift;
    _debug(q{});
    if ( $self->{ +_CURRENT }->realtime ) {
        _debug('Running in realtime mode');
        _debug(
            '...previous events will be flushed as soon as the next test arrives'
        );
    }
    else {
        _debug('Not in realtime mode');
        _debug(
            '...buffering formatter output until all tests in subtest have arrived'
        );
    }
    _debug( 'Received ' . ref $event );
    _debug( '-> ' . ( $event->name // q{} ) )
        if $event->isa('Test2::Event::Ok');
    _debug( '-> ' . $event->message )
        if $event->isa('Test2::Event::Note')
        || $event->isa('Test2::Event::Message');
}

## no critic (Subroutines::ProhibitBuiltinHomonyms)
# We've got no choice but to call this 'write' - that's the public API
# for Test2 formatters
sub write {
    my $self  = shift;
    my $event = shift;

    return if $event->no_display;

    # Test::Builder sends an extra Diag event after finalizing when tests
    # fail.
    return if $self->{ +_FINALIZED };

    $self->_debug_event($event);

    # set a timestamp on the event if there's not one already
    # note that this use of 'timestamp' is completely proprietary to this
    # teamcity test2 distribution
    unless ( $event->get_meta('timestamp') ) {
        $event->set_meta( timestamp => tc_timestamp() );
    }

    # Subtests come in two distinct flavors: Buffered and streaming, both of
    # which the event for are only delivered *after* all the events are
    # generated for the tests contained within the subtest
    #
    # Buffered subtests don't deliver any "child" events for the tests inside
    # the buffered subtest at all to the formatter's write method - when the
    # buffered subtest event turns up you have to replay the events that are
    # stored in the buffered subtest event's subtests method.
    #
    # Streaming subtests deliver the events for the subtests as they happen but
    # there's no indication that a subtest has just started - you need to pay
    # attention to the subtest_id and nested attributes of every test event that
    # comes in to check if it's actually a test contained within a subtest
    # operating at a different level to what you're currently processing
    # and start the event there and then.
    #
    # This is all complicated by the fact that the teamcity grammar for subtests
    # is called testSuiteStarted and testSuiteFinsihed and these *both* need
    # the name of the subtest, so you can't start outputting a subtest till you
    # have a name for it.

    if ( !$event->isa('Test2::Event::Subtest') ) {
        _debug('-> event itself is not a subtest');

        # If this event is part of a streaming subtest, then it may be the
        # first event in that subtest, in which case we need to start a new
        # suite. The Subtest event will come later and finish the suite we
        # start.
        my $did_start_suite = $self->_maybe_start_suite($event);

        # are we outputing the event in "realtime"?  This means that as soon as
        # we start a new test (and therefore we're done collecting all the diag
        # etc that followed the previous test) we flush out the events in the
        # buffer that are now done with.
        my $realtime = $self->{ +_CURRENT }->realtime;
        if ( $realtime && $event->increments_count ) {
            $self->_flush_current_children_events;
        }

        $self->{ +_CURRENT }->add_child($event);

        # if we just finished a job we might as well flush the child events
        # right away without waiting for the next test to start for more
        # responsiveness - we're not getting any more output after that after
        # all!
        if ( $realtime && $event->isa('Test2::Event::TeamCity::FinishJob') ) {
            $self->_flush_current_children_events;
        }
        return;
    }

    _debug('-> event itself is a subtest');

    # If the event is buffered, we start a new suite, replay all the
    # subevents, and then finish the suite.
    if ( $event->buffered ) {
        _debug('   -> a buffered subtest');
        $self->_start_suite(
            $event->subtest_id,
            $event->nested,
            $event->name,
        );
        $self->write($_) for @{ $event->subevents };
        $self->_finish_suite( $event->subtest_id );

        return;
    }

    _debug('   -> a streaming subtest');
    $self->{ +_CURRENT }->set_name( $event->name );
    $self->_finish_suite( $event->subtest_id );

    return;
}
## use critic

sub _flush_current_children_events {
    my $self     = shift;
    my $children = $self->{ +_CURRENT }->children;
    _debug( '--> flushing ' . @{$children} . ' child events' );
    _debug( '----> ' . ref ) for @{$children};
    $self->_children_to_tc($children);
    return;
}

sub _maybe_start_suite {
    my $self  = shift;
    my $event = shift;

    # don't start a new suite if this is a top level event
    return unless $event->nested;

    # don't start a new suite if there is no parent event (this shouldn't
    # happen, but hey...)
    my $id = $event->in_subtest;
    return unless _not_empty($id);

    # don't start a new suite this event belongs in the current suite
    return if $id eq $self->{ +_CURRENT }->id;

    $self->_start_suite( $id, $event->nested );

    return;
}

sub _start_suite {
    my $self  = shift;
    my $id    = shift;
    my $depth = shift;
    my $name  = shift;

    _debug( 'Starting new suite: ' . $id );

    if ( _not_empty($name) && ( $depth // 0 ) < 2 ) {
        my $full_name;
        $full_name = $self->{ +_CURRENT }->name . q{ - }
            if $self->{ +_CURRENT };
        $full_name .= $name;

        $self->_tc_message(
            progressMessage => "starting $full_name",
        );
    }

    my $realtime = _not_empty($name)
        && ( !$self->{ +_CURRENT } || $self->{ +_CURRENT }->realtime );
    if ($realtime) {
        _debug('-> which will be outputting in real time');
    }
    else {
        _debug('-> which will not be outputting in real time');
    }

    my $suite = Test2::Formatter::TeamCity::Suite->new(
        id       => $id,
        name     => $name,
        parent   => $self->{ +_CURRENT },
        realtime => $realtime,
    );

    if ( $self->{ +_CURRENT } ) {
        if ( $self->{ +_CURRENT }->realtime ) {

            # flush out any events we've been building up in our parent
            # since we're starting a new subtest
            $self->_flush_current_children_events;
        }
        else {
            # record this subtest (we don't need to do this if we're
            # outputting in realtime because by the time we're done
            # we'll have already output everything
            $self->{ +_CURRENT }->add_child($suite);
        }
    }

    $self->{ +_TOP } //= $suite;
    $self->{ +_CURRENT } = $suite;

    if ( $suite->realtime ) {
        $self->_tc_message(
            testSuiteStarted => {
                name => $name,
            }
        );
    }

    return;
}

sub _finish_suite {
    my $self = shift;
    my $id   = shift;

    _debug( 'finish suite: ' . $id );

    unless ( $self->{ +_CURRENT } ) {
        warn 'Called _finish_suite before any suites were started';
        return;
    }

    while (1) {
        my $last_suite = $self->{ +_CURRENT }{id};
        last if $last_suite eq $id;

        warn
            "Last suite on the stack ($last_suite) does not match suite we want to finish ($id)";

        $self->_finish_suite($last_suite);
    }

    if ( $self->{ +_CURRENT }->realtime ) {

        # if we're running in realtime then we need to output any remaining
        # child events and finish the suite *right* *now*

        # flush out any events still in the queue.
        $self->_children_to_tc( $self->{ +_CURRENT }->children );

        $self->_tc_message(
            testSuiteFinished => {
                name => $self->{ +_CURRENT }->name,
            }
        );
    }
    elsif ($self->{ +_CURRENT }->parent
        && $self->{ +_CURRENT }->parent->realtime ) {

        # if our parent was running in realtime then it's time to
        # render ourselves out now we're done
        $self->_suite_to_tc( $self->{ +_CURRENT } );
    }

    $self->{ +_CURRENT } = $self->{ +_CURRENT }->parent;

    return;
}

sub terminate {
    my $self  = shift;
    my $event = shift;

    _debug('terminate');

    # If we are in the middle of one or more subtests we need to close them
    # out or we will not generate valid output for TC.
    while ( $self->{ +_CURRENT }->parent ) {
        $self->_finish_suite( $self->{ +_CURRENT }->id );
    }

    # If $event->terminate is true then this is a bail out event, otherwise
    # it's a skip_all.
    if ( $event->terminate ) {
        my $text
            = _not_empty( $event->reason )
            ? 'teminate was called: ' . $event->reason
            : 'terminate event with no reason provided';
        $self->_tc_message(
            message => {
                text   => $text,
                status => 'ERROR',
            },
        );
    }

    # The finalize method will be called for a non-Bail terminate.
    $self->_finalize if $event->terminate;

    return;
}

sub finalize {
    my $self = shift;
    shift;
    shift;
    shift;
    shift;
    my $is_subtest = shift;

    _debug('finalize');

    return if $is_subtest;

    _debug('   -> finalize is not subtest');

    $self->_finish_suite( $self->{ +_TOP }->id );

    $self->{ +_FINALIZED } = 1;
    $self->_finalize;

    return;
}

sub _finalize {
    my $self = shift;

    $self->_suite_to_tc( $self->{ +_TOP } );

    return;
}

sub _suite_to_tc {
    my $self  = shift;
    my $suite = shift;

    # if this suite was being rendered in realtime, we don't need to do
    # anything - everything has already been rendered out
    return if $suite->realtime;

    # We could end up with a nameless suite if a streamed subtest is started
    # and then bail is called mid-subtest. We would never see the ending
    # subtest event.
    my $name = $suite->name // 'NO SUITE NAME';
    $self->_tc_message(
        testSuiteStarted => {
            name => $name,
        }
    );

    $self->_children_to_tc( $suite->children );

    $self->_tc_message(
        testSuiteFinished => {
            name => $name,
        }
    );
}

# Subtests should be handled already, and should not be included in our list
# of events.
my %METHODS = (
    'Test2::Event::Ok'                => '_event_ok',
    'Test2::Event::Skip'              => '_event_skip',
    'Test2::Event::Note'              => '_event_note',
    'Test2::Event::Diag'              => '_event_diag',
    'Test2::Event::Bail'              => '_event_bail',
    'Test2::Event::Exception'         => '_event_exception',
    'Test2::Event::Plan'              => '_event_plan',
    'Test2::Event::TeamCity::Message' => '_event_tc_message',
    'Test2::Event::Waiting'           => '_event_waiting',
);

sub _children_to_tc {
    my $self     = shift;
    my $children = shift;

    while ( my $child = shift @{$children} ) {
        if ( $child->isa('Test2::Formatter::TeamCity::Suite') ) {
            $self->_suite_to_tc($child);
        }
        else {
            my $method = $METHODS{ ref $child } // '_event_other';
            my @extra;
            if ( $method eq '_event_ok' ) {
                while ( @{$children}
                    && $children->[0]->isa('Test2::Event::Diag') ) {
                    push @extra, shift @{$children};
                }
            }

            $self->$method( $child, @extra );
        }
    }
}

## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
# Perl critic isn't clever enough to realize the _event_* methods are
# called from the dispatch %METHODS hash within this class
sub _event_ok {
    my $self  = shift;
    my $event = shift;
    my @extra = @_;

    my $name = $self->_name_for_event($event);
    if ( defined $event->todo ) {
        $name .= ' - TODO';
        $name .= q{: } . $event->todo if length $event->todo;
    }

    $self->_start_test($name);

    if ( $event->causes_fail ) {
        my $diag = join q{}, map { $_->message } @extra;
        $self->_fail_test( $name, $diag );
    }
    elsif (@extra) {
        $self->_event_diag($_) for @extra;
    }

    $self->_finish_test($name);

    return;
}

sub _event_skip {
    my $self  = shift;
    my $event = shift;

    my $name = $self->_name_for_event($event);
    $self->_start_test($name);

    my $reason = $event->reason;
    $self->_tc_message(
        testIgnored => {
            name => $name,
            ( _not_empty($reason) ? ( message => $reason ) : () ),
        },
    );

    $self->_finish_test($name);

    return;
}

sub _event_note {
    my $self  = shift;
    my $event = shift;

    $self->_tc_message( message => { text => $event->message } );

    return;
}

sub _event_diag {
    my $self  = shift;
    my $event = shift;

    $self->_tc_message( message => { text => $event->message } );

    return;
}

# This will be handle in the terminate method
sub _event_bail {
    my $self = shift;

    return;
}

sub _event_exception {
    my $self  = shift;
    my $event = shift;

    $self->_tc_message(
        message => {
            text => ( $event->error // 'exception event with no error' ),
            status => 'ERROR',
        }
    );

    return;
}

sub _event_plan {
    my $self  = shift;
    my $event = shift;

    return unless defined $event->directive && $event->directive eq 'SKIP';

    $self->_start_test('Skipped');
    $self->_tc_message(
        testIgnored => {
            name    => 'Skipped',
            message => $event->reason // 'plan skip_all with no reason given',
        },
    );
    $self->_finish_test('Skipped');

    return;
}

sub _event_tc_message {
    my $self  = shift;
    my $event = shift;

    $self->_tc_message(
        message => {
            text   => $event->text,
            status => $event->status,
        }
    );

    return;
}

sub _event_waiting {
    return;
}

sub _event_other {
    my $self  = shift;
    my $event = shift;

    # die "Unexpected event! $event";
}
## use critic

sub _name_for_event {
    my $self  = shift;
    my $event = shift;

    my $name = $event->name;
    return $name if _not_empty($name);

    if (   $event->isa('Test2::Event::Ok')
        || $event->isa('Test2::Event::Skip') ) {

        return 'NO TEST NAME';
    }
    elsif ( $event->isa('Test2::Event::Subtest') ) {
        return 'NO SUBTEST NAME';
    }
    else {
        return 'NO EVENT NAME';
    }
}

sub _start_test {
    my $self = shift;
    my $name = shift;

    $self->_tc_message(
        testStarted => {
            name => $name,
        }
    );

    return;
}

sub _fail_test {
    my $self = shift;
    my $name = shift;
    my $diag = shift;

    $self->_tc_message(
        testFailed => {
            name    => $name,
            message => 'not ok',
            ( _not_empty($diag) ? ( details => $diag ) : () ),
        },
    );

    return;
}

sub _finish_test {
    my $self = shift;
    my $name = shift;

    $self->_tc_message(
        testFinished => {
            name => $name,
        },
    );

    return;
}

sub _tc_message {
    my $self    = shift;
    my $type    = shift;
    my $content = shift;

    if ( ref $content ) {
        $content->{flowId} ||= $0;

    }

    print { $self->{ +_HANDLE } } tc_message(
        type    => $type,
        content => $content,
    ) or die $!;

    return;
}

sub _not_empty {
    return defined $_[0] && length $_[0];
}

1;

__END__

# ABSTRACT: Test2 formatter producing TeamCity compatible output

=for Pod::Coverage
    init
    hide_buffered encoding write terminate finalize
