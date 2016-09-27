package Test2::Formatter::TeamCity;

use strict;
use warnings;

use parent 'Test2::Formatter';

use TeamCity::Message qw( tc_message );
use Test2 1.0203060 ();
use Test2::Formatter::TeamCity::Suite;

# The no_* attributes are solely there so Test::Builder doesn't complain. What
# they're set to has no impact on the output from this Formatter class.
use Test2::Util::HashBase
    qw( no_diag no_header no_numbers _handle _current _finalized _top );

sub init {
    my $self = shift;

    open my $fh, '>&', STDOUT or die "Can't dup STDOUT: $!";
    $fh->autoflush(1);
    $self->{ +_HANDLE } = $fh;

    $self->_start_suite( $0, 0, $0 );

    return;
}

sub hide_buffered {1}

sub write {
    my $self  = shift;
    my $event = shift;

    return if $event->no_display;

    # Test::Builder sends an extra Diag event after finalizing when tests
    # fail.
    return if $self->{ +_FINALIZED };

    if ( $event->isa('Test2::Event::Subtest') ) {

        # If the event is buffered, we start a new suite, replay all the
        # subevents, and then finish the suite.
        if ( $event->buffered ) {
            $self->_start_suite(
                $event->subtest_id,
                $event->nested,
                $event->name,
            );
            $self->write($_) for @{ $event->subevents };
            $self->_finish_suite( $event->subtest_id );
        }

        # If it's a streaming subtest, we've already seen all of its
        # subevents, so we just need to finish the suite.
        else {
            $self->{ +_CURRENT }->set_name( $event->name );
            $self->_finish_suite( $event->subtest_id );
        }
    }
    else {
        # If this event is part of a streaming subtest, then it may be the
        # first event in that subtest, in which case we need to start a new
        # suite. The Subtest event will come later and finish the suite we
        # start.
        $self->_maybe_start_suite($event);
        $self->{ +_CURRENT }->add_child($event);
    }

    return;
}

sub _maybe_start_suite {
    my $self  = shift;
    my $event = shift;

    return unless $event->nested;

    my $id = $event->in_subtest;
    return unless _not_empty($id);

    return if $id eq $self->{ +_CURRENT }->id;

    $self->_start_suite( $id, $event->nested );

    return;
}

sub _start_suite {
    my $self  = shift;
    my $id    = shift;
    my $depth = shift;
    my $name  = shift;

    if ( _not_empty($name) && ( $depth // 0 ) < 2 ) {
        my $full_name;
        $full_name = $self->{ +_CURRENT }->name . q{ - }
            if $self->{ +_CURRENT };
        $full_name .= $name;

        $self->_tc_message(
            progressMessage => "starting $full_name",
        );
    }

    my $suite = Test2::Formatter::TeamCity::Suite->new(
        id     => $id,
        name   => $name,
        parent => $self->{ +_CURRENT },
    );

    if ( $self->{ +_CURRENT } ) {
        $self->{ +_CURRENT }->add_child($suite);
    }

    $self->{ +_TOP } //= $suite;
    $self->{ +_CURRENT } = $suite;

    return;
}

sub _finish_suite {
    my $self = shift;
    my $id   = shift;

    unless ( $self->{ +_CURRENT } ) {
        warn 'Called _finish_suite before any suites were started';
        return;
    }

    my $last_suite = $self->{ +_CURRENT }{id};
    unless ( $last_suite eq $id ) {
        warn
            "Last suite on the stack ($last_suite) does not match suite we want to finish ($id)";
    }

    $self->{ +_CURRENT } = $self->{ +_CURRENT }->parent;

    return;
}

sub terminate {
    my $self  = shift;
    my $event = shift;

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

    return if $is_subtest;

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
    'Test2::Event::Waiting' => '_event_waiting',
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
    my $self  = shift;
    my $event = shift;

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

    die "Unexpected event! $event";
}

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
    my $self         = shift;
    my $type         = shift;
    my $content      = shift;
    my $force_stdout = shift;

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
