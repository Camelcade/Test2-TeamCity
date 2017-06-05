#!/usr/bin/perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use FindBin;
use File::Spec::Functions qw( catdir updir );
use lib catdir($FindBin::Bin, updir, updir, 'lib');
use TestSync qw( wait_for_notification send_notification );

# wait for the second to start failing
wait_for_notification('second-has-failed');
send_notification('second-has-failed-received-by-fifth');

ok(1, 'thirteen twighlight sparkle');
ok(1, 'fourteen pinky pie');
ok(1, 'fifthteen rarity');
ok(1, 'sixteen applejack');
ok(1, 'seventeen rainbow dash');
ok(1, 'eighteen fluttershy');

# don't complete until everything else has
wait_for_notification('third-completed');
wait_for_notification('fourth-completed');

done_testing();

