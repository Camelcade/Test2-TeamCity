use strict;
use warnings;

use Test::More;
use Test2::TeamCity qw( tc_message );

tc_message('before');

ok 1, 'ok';

tc_message( WARNING => 'after' );

done_testing;
