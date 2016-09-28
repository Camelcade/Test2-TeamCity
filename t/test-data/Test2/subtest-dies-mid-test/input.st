use strict;
use warnings;

use Test2::Bundle::Extended;

ok 1, 'subtest-dies-mid-test-msg-1';

subtest 'subtest-A-name', sub {
    ok 1, 'subtest-dies-mid-test-msg-2';
    exit 42;
};

done_testing;
