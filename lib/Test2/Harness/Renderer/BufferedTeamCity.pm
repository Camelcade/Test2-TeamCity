package Test2::Harness::Renderer::BufferedTeamCity;

use strict;
use warnings;

# we can't use ':all' here as that'll attempt to wrap the built-in listen,
# but this module needs to implement a
use autodie qw( open close );

our $VERSION = '0.000001';

use List::Util 1.33 qw( none );
use File::Temp qw( tempfile );
use Path::Class qw( file );
use TeamCity::Message 0.02 qw( tc_message tc_timestamp );
## no critic (BuiltinFunctions::ProhibitStringyEvse critic
use Term::ANSIColor qw( color );
use Test2::Event::TeamCity::FinishJob;
use Test2::Event::TeamCity::StartJob;
use Test2::Formatter::TeamCity;

# this creates accessor methods for each of these, as well as exporting
# uppercase constants for accessing them from the blessed hashref directly
use Test2::Util::HashBase qw(
    _formatter
    _buffers
    _realtime_queue
    _ready_queue
    _job_name
);

sub DEBUG { $ENV{TEST2_TEAMCITY_VERBOSE} }

# this is the "constructor" - called by hashbase when the user calls new
sub init {
    my $self = shift;

    # this is the formatter that will render all our output.
    $self->{ +_FORMATTER } = Test2::Formatter::TeamCity->new();

    # this is a hashref indexed by job id, with each value being an array of
    # cached events
    $self->{ +_BUFFERS } = {};

    # a list of job_ids that are completed and ready to be output (i.e. jobs for
    # which we've seen a Test2::Event::ProcessFinish or
    # Test2::Event::UnexpectedProcessExit event).  Things normally only pass
    # through this queue briefly on their way to be output straight away, but if
    # something is being output in realtime then we can't output right away
    # without mixing up our output, so this queue will grow.
    $self->{ +_READY_QUEUE } = [];

    # a list of job_ids that have failing tests and should be output in
    # realtime if possible.  The first element of this list is currently
    # being output in realtime
    $self->{ +_REALTIME_QUEUE } = [];

    $self->{ +_JOB_NAME } = {};

    return;
}

sub _job_name_for_job_id {
    my $self   = shift;
    my $job_id = shift;
    return $self->{ +_JOB_NAME }{$job_id};
}

sub _add_event_to_buffer {
    my $self   = shift;
    my $job_id = shift;
    my $event  = shift;

    push @{ $self->{ +_BUFFERS }{$job_id} }, $event;
}

########################################################################
# external interface

# the subroutine that listen returns is the main interface to the rest of
# Test2::Harness.  It's called once and should return a coderef that will be
# passed each job/event pair each time an event is posted
# We have to turn off perl critic here because Test2::Harness defines this
# interface, so we have to name our subroutine that
## no critic (ProhibitBuiltinHomonyms)
sub listen {
    my $self = shift;
    return sub {
        my $job   = shift;
        my $event = shift;

        DEBUG() && $self->_output_start_banner_debugging( $job, $event );

        $self->_possibly_add_timestamp_to_event($event);
        $self->_possibly_setup_this_job($job);

        DEBUG() && $self->_output_per_event_debugging( $job, $event );

        $self->_process_this_event( $job, $event );

        DEBUG() && $self->_output_queue_state_debugging($event);

        $self->_flush_buffers_as_much_as_possible;

        return;
    };
}
## use critic

sub summary {
    my $self = shift;

    $self->{ +_FORMATTER }->finalize;

    return;
}

########################################################################
# non-debug methods called from the listen anonymous subroutine

# this just puts a timestamp on the event (using a proprietary field in the the
# meta settings) so that we can report the real time we got the events when we
# replay the buffer later in the formatter.
sub _possibly_add_timestamp_to_event {
    my $self  = shift;
    my $event = shift;

    unless ( $event->get_meta('timestamp') ) {
        $event->set_meta( timestamp => tc_timestamp() );
    }

    return;
}

# we setup each job only once the first time we see a new job id, giving it a
# name we remember and queuing a Test2::Event::TeamCity::StartJob event for it
sub _possibly_setup_this_job {
    my $self   = shift;
    my $job    = shift;
    my $job_id = $job->id;

    # don't do anything if we've already setup this job
    return if defined $self->{ +_JOB_NAME }{$job_id};

    my $file = file( $job->file )->relative;
    my $name = "script-$file";
    $self->{ +_JOB_NAME }{$job_id} = $name;

    # setup the buffer with a custom TC event for starting the job
    my $job_start_event = Test2::Event::TeamCity::StartJob->new(
        name => $name,
    );
    $job_start_event->set_meta( 'timestamp', tc_timestamp() );
    $self->{ +_BUFFERS }{$job_id} = [$job_start_event];

    return;
}

# processes the event, most likely buffering it
sub _process_this_event {
    my $self  = shift;
    my $job   = shift;
    my $event = shift;

    my $job_id = $job->id;

    # did we just start a new job?  Don't propagate the event
    if ( $event->isa('Test2::Event::ProcessStart') ) {
        return;
    }

    # is this done? Don't propagate the event, but do record when it happened
    if ( $event->isa('Test2::Event::ProcessFinish') ) {
        $self->_add_to_ready_queue($job_id);
        return;
    }
    if ( $event->isa('Test2::Event::UnexpectedProcessExit') ) {

        # TODO: RENDER ERRORS AS TC STUFF
        # TODO: we need to be careful here to DTRT with half finished output
        $self->_add_to_ready_queue($job_id);
        return;
    }

    # buffer the event.
    $self->_add_event_to_buffer( $job_id, $event );

    # is this a test failure?  We want to start displaying this one
    # as soon as possible then, so move it to the realtime queue
    if ( $event->causes_fail ) {
        $self->_add_to_realtime_queue($job_id);
    }

    return;
}

# clear out the events stored in the job buffers and flush them to the formatter
# if we can (i.e. if doing so wouldn't mix the output from the various jobs.)
# Note that the formatter has it's own buffer (so it can associate diags,
# unexpected stdout, stderr, etc, that follow a test with that test) so even
# when it's flushed from here it might not actually be printed out right away.
sub _flush_buffers_as_much_as_possible {
    my $self = shift;

    # skip everything if there's nothing in any queue
    return
        if !@{ $self->{ +_REALTIME_QUEUE } }
        && !@{ $self->{ +_READY_QUEUE } };

    # are we currently outputting a job in realtime?
    unless ( @{ $self->{ +_REALTIME_QUEUE } } ) {

        # since we're not outputting a job in realtime, we can simply
        # dump anything that's ready out
        _debug('Nothing in the realtime queue...');
        $self->_flush_ready_queue;

        # we've processed both real time and ready queues, we're done
        return;
    }

    # Since there's something in the real time queue then...
    _debug('Events occur in real time');

    # output everything that's buffered for the job at the very top of the
    # realtime queue since that can be sent right away
    my $job_id = $self->{ +_REALTIME_QUEUE }[0];
    _debug(
        " - @{[ $self->_job_name_for_job_id( $job_id )]} is head of the real time queue"
    );
    $self->_flush_buffer($job_id);

    # has the job we're currently outputting in realtime been marked as ready?
    return if none { $_ eq $job_id } @{ $self->{ +_READY_QUEUE } };
    _debug(
        "the realtime job @{[ $self->_job_name_for_job_id( $job_id ) ]} is complete!"
    );

    # since we're not right in the middle of updating in realtime now, we
    # can now flush the ready queue!

    # STEP 1: Remove everything in the ready queue from the realtime
    # queue since we're about to flush it out and we no longer need
    # to track it
    my %to_delete = map { $_ => 1 } @{ $self->{ +_READY_QUEUE } };
    @{ $self->{ +_REALTIME_QUEUE } }
        = grep { !$to_delete{$_} } @{ $self->{ +_REALTIME_QUEUE } };

    # STEP 2: flush everything in the ready queue out
    $self->_flush_ready_queue;

    return;
}

########################################################################
# support methods

sub _flush_ready_queue {
    my $self = shift;
    return unless @{ $self->{ +_READY_QUEUE } };

    _debug('Flushing ready queue');
    while ( @{ $self->{ +_READY_QUEUE } } ) {
        my $job_id = shift @{ $self->{ +_READY_QUEUE } };
        _debug(
            " * '@{[ $self->_job_name_for_job_id( $job_id ) ]}' will be flushed"
        );
        $self->_flush_buffer($job_id);
    }
    return;
}

# flushes the buffer for the given job_id to the formatter
sub _flush_buffer {
    my $self   = shift;
    my $job_id = shift;
    _debug(
        "Flushing job-level buffer for @{[ $self->_job_name_for_job_id( $job_id ) ]}"
    );

    my $buffer = $self->{ +_BUFFERS }{$job_id} or return;
    while ( @{$buffer} ) {
        $self->{ +_FORMATTER }->write( shift @{$buffer} );
    }
}

sub _add_to_realtime_queue {
    my $self   = shift;
    my $job_id = shift;

    my $realtime_queue = $self->{ +_REALTIME_QUEUE };

    # don't add if it's already in the queue
    return if grep { $_ == $job_id } @{$realtime_queue};

    _debug(
        "Adding @{[ $self->_job_name_for_job_id( $job_id ) ]} to the real time queue"
    );

    # add to the queue in order
    push @{$realtime_queue}, $job_id;

    return;
}

# add this job to the ready queue
sub _add_to_ready_queue {
    my $self   = shift;
    my $job_id = shift;

    _debug(
        "Adding @{[ $self->_job_name_for_job_id( $job_id ) ]} to the ready queue"
    );

    # add event saying we're done
    my $finish_event = Test2::Event::TeamCity::FinishJob->new(
        name => $self->{ +_JOB_NAME }{$job_id},
    );
    $finish_event->set_meta( 'timestamp', tc_timestamp() );
    $self->_add_event_to_buffer( $job_id, $finish_event );

    # and add the job to the queue
    push @{ $self->{ +_READY_QUEUE } }, $job_id;

    return;
}

########################################################################
# debugging utilities

sub _debug {
    return unless DEBUG();
    for (@_) {
        print STDERR color('black')
            . color('on_cyan')
            . $_
            . color('reset') . "\n";
    }
}

sub _should_debug {
    my $self  = shift;
    my $event = shift;

    # # ignore some events
    # return
    #     if ref($event)
    #     =~ /\ATest2::Event::(?:Process(?:Start|Finish)|Encoding|ParserSelect|Plan|)\z/;

    return 1;
}

{
    my $n = 0;

    sub _output_start_banner_debugging {
        my $self  = shift;
        my $job   = shift;
        my $event = shift;

        return unless $self->_should_debug($event);

        $n++;
        print STDERR color('green'), "== $n ", '=' x 60, color('reset'), "\n";
    }
}

sub _output_queue_state_debugging {
    my $self  = shift;
    my $event = shift;

    return if DEBUG() < 2;
    return unless $self->_should_debug($event);

    print STDERR color('magenta'), '    READY QUEUE: ',
        join(
        ',',
        map { $self->_job_name_for_job_id($_) } @{ $self->{ +_READY_QUEUE } }
        ),
        color('reset'), "\n";
    print STDERR color('magenta'), 'REAL TIME QUEUE: ',
        join(
        ',',
        map { $self->_job_name_for_job_id($_) }
            @{ $self->{ +_REALTIME_QUEUE } }
        ),
        color('reset'), "\n";
    for my $job_id ( sort keys %{ $self->{ +_BUFFERS } } ) {
        my $name = $self->_job_name_for_job_id($job_id);
        print STDERR color('magenta'), " * $name: ";
        print STDERR join ',', map {ref} @{ $self->{ +_BUFFERS }{$job_id} };
        print STDERR color('reset'), "\n";

    }
}

sub _output_per_event_debugging {
    my $self  = shift;
    my $job   = shift;
    my $event = shift;

    return if DEBUG() < 2;
    return unless $self->_should_debug($event);

    # this copes with things not implementing ->todo etc even though the
    # documentation says that the base class should do
    my $e = sub {
        my $resolved_method = $event->can(shift);
        return q{} unless $resolved_method;
        my $result = $resolved_method->($event);
        return $result // q{};
    };

    my $string = <<"THEEND";
job '@{[ $job->file ]}' emitted a @{[ color('red'), ref $event ]}
   causes_fail:       @{[ $e->('causes_fail')      ? 'true' : 'false ']}
   increments_count:  @{[ $e->('increments_count') ? 'true' : 'false ']}
   nested:            @{[ $e->('nested')   ]}
   summary:           @{[ $e->('summary')  ]}
   todo:              @{[ $e->('todo')     ]}
   plan:
     count:           @{[ ($event->sets_plan)[0] // '' ]}
     directive:       @{[ ($event->sets_plan)[1] // '' ]}
     reason:          @{[ ($event->sets_plan)[2] // '' ]}
   in_subtest:        @{[ $e->('in_subtest') ]}
   subtest_id:        @{[ $e->('subtest_id') ]}
@{[ color('reset') ]}
THEEND

    print STDERR _pad( $string, $e->('nested') || 0 );
}

sub _pad {
    my $string = shift;
    my $value  = shift;
    my $chr    = length($value) < 2 ? $value : '*';
    $chr = $chr x ( $value * 4 );
    $chr = color('blue') . $chr . color('cyan');
    $string =~ s/^/$chr /mg;
    $string .= color('reset');
    return $string;
}

########################################################################

1;

__END__

=for Pod::Coverage
  init
  listen
  summary

=head1 DESCRIPTION

This is a prototype for a TeamCity renderer.  It buffers up all test2 events
for the duration of the test run and then outputs them in one fail swoop at
the end.

This uses the Test2 legacy event API.  It'll do for now.



