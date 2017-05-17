#!/usr/bin/perl

# this should be output after the first

# it'll start as soon as the first is done (and has been output)
# it won't complete until fourth has started failing (and is on the real time
# queue)
# it won't complete unitl the third is done (which means third will be output
# as soon as we're done)

use strict;
use warnings;

use Test2::Bundle::Extended;
use FindBin;
use File::Spec::Functions qw( catdir updir );
use lib catdir($FindBin::Bin, updir, updir, 'lib');
use TestSync qw(
    wait_for_events_to_be_processed
    wait_for_notification
    send_notification
);

wait_for_notification('first-completed');

ok(1, 'four rod');
send_notification('rod');

# wait for fourth.st to get started, but since neither of us should
# be running in realtime now, we're both buffering the events
wait_for_notification('fred');

# now send a breaking test.  This should shift this script to the realtime
# queue and start outputting this script in real time.
ok(0, 'five jane');
send_notification('second-has-failed');
wait_for_notification('second-has-failed-received-by-third');
wait_for_notification('second-has-failed-received-by-fourth');
wait_for_notification('second-has-failed-received-by-fifth');

print STDERR <<'END';
 - this text is sent to STDERR
 - it should be reported as part of the failing test
END

# we should be rendering in realtime now.  Wait for fourth.st to render its
# own failure event, which will put it onto the realtime queue, but since we're
# at the head of the queue now, it's not going to be doing anything
wait_for_notification('fourth-has-failed');
send_notification('fourth-has-failed-received-by-second');
ok(1, 'six freddy');

# okay, these 'wait_for_events_to_be_processed' routines are glossing over a
# real failure we'll see in our actual output - that STDERR and STDOUT aren't
# normally completely synchronized and that sometimes this will result in STDERR
# being reported as part of a previous / subsequent test as random STDERR gets
# processed before the corresponding STDOUT that the test events that switch
# tests are sent to.  There's really nothing I can do about that (it's an OS
# problem) but we can simulate the OS getting it right (which it will some of
# the time) with the 'wait_for_events_to_be_processed' and then check in that
# situation we at least get the output we expect!
wait_for_events_to_be_processed();
print STDERR <<'END';
 - more text is sent to STDERR
 - it should be reported as messages
END
wait_for_events_to_be_processed();

# wait for the third test to compeltely finish.  This should be immediately
# flushed as soon as we're done
wait_for_notification('third-completed');

# when we're done with this test file the third test should be output
# straight away (because it's totally done) then the fourth test should be
# output in realtime
done_testing();

