use strict;
use warnings;

use Test2::Bundle::Extended;

ok 1, 'subtest-todo-msg-1';

subtest 'subtest-A-name', sub {
    ok 1, 'subtest-todo-msg-2';

    todo 'not expected to pass', sub {
        ok 1, 'subtest-todo-msg-3';
        ok 0, 'subtest-todo-msg-4';
    };
};

done_testing;
