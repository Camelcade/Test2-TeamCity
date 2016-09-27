use strict;
use warnings;

use Test::More;

ok 1, 'simple-dies-mid-test-msg-1';

die 'dying after the first ok';

done_testing;
