use strict;
use warnings;

use lib 't/lib';

use Test::Class::Moose::Runner;

use Test2::Formatter::TeamCity::Test::SimpleSkip;
use Test2::Formatter::TeamCity::Test::SimpleOK;

Test::Class::Moose::Runner
    ->new(test_classes => [qw(
        Test2::Formatter::TeamCity::Test::SimpleSkip
        Test2::Formatter::TeamCity::Test::SimpleOK)])
    ->runtests;

