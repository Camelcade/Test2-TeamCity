#!/usr/bin/perl

# this should run first to completion and get dumped out because it's
# at the top of the ready queue.
#
# second is waiting for the 'first-completed' notification this sends when
# it is done
#
# third is waiting for the 'fourth-has-failed' notification which it can't get
# till after forth has seen 'second-has-failed', and second is waiting on the
# 'first-completed' notification this sends when it is done
#
# fourth is waiting on 'second-has-failed', and second is waiting on the
# 'first-completed' notification this sends when it is done
#
# fifth is waiting on 'second-has-failed', and second is waiting on the
# 'first-completed' notification this sends when it is done

use strict;
use warnings;

use Test2::Bundle::Extended;
use FindBin;
use File::Spec::Functions qw( catdir updir );
use lib catdir($FindBin::Bin, updir, updir, 'lib');
use TestSync qw( wait_for_notification send_notification );

ok(1, 'one alpha');
ok(1, 'two bravo');
ok(1, 'three charlie');

done_testing();
