#!/usr/bin/perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use FindBin;
use File::Spec::Functions qw( catdir updir );
use lib catdir($FindBin::Bin, updir, updir, 'lib');
use TestSync qw( wait_for_notification send_notification );

ok(1, 'ten fred');
send_notification('fred');

# this test only emits a failure *after* second.st starts to fail
# this failure should put us on the real time queue right after second.st
# but we shouldn't output anything just yet
wait_for_notification('second-has-failed');
send_notification('second-has-failed-received-by-fourth');

ok(0, 'eleven barney');

send_notification('fourth-has-failed');
wait_for_notification('fourth-has-failed-received-by-second');
wait_for_notification('fourth-has-failed-received-by-third');

wait_for_notification('third-completed');

print STDOUT <<'END';
This is STDOUT following *a failing test*.  It should be reported as part of
the reason the test failed.
END

ok(1, 'twelve freddy');

print STDOUT <<'END';
This is STDOUT following *a passing test*.  It should be reported as new
messages each time.
END

done_testing();

