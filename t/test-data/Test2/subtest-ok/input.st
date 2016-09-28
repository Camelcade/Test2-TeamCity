use strict;
use warnings;

use Test2::Bundle::Extended;

ok 1, 'subtest-ok-msg-1';

subtest 'subtest-A-name', sub {
    ok 1, 'subtest-ok-msg-2';
};

done_testing;
