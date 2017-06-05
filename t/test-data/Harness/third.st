#!/usr/bin/perl

# this should be output third, after first and second

# this should start running after second has failed
# this should start running after fourth has failed

# this should complete running before second has completed

use strict;
use warnings;

use Test2::Bundle::Extended;
use FindBin;
use File::Spec::Functions qw( catdir updir );
use lib catdir($FindBin::Bin, updir, updir, 'lib');
use TestSync qw( wait_for_notification send_notification );

wait_for_notification('second-has-failed');
send_notification('second-has-failed-received-by-third');

wait_for_notification('fourth-has-failed');
send_notification('fourth-has-failed-received-by-third');

ok(1, 'seven bubbles');
ok(1, 'eight buttercup');
ok(1, 'nine blossom');

done_testing();
