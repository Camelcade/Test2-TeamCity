use strict;
use warnings;

use lib 't/lib';

use Test::Class::Moose::Runner;

use Test2::Formatter::TeamCity::Test::SimpleOK;
use Test2::Formatter::TeamCity::Test::SimpleFail;

Test::Class::Moose::Runner
    ->new(test_classes => [qw(
        Test2::Formatter::TeamCity::Test::SimpleOK
        Test2::Formatter::TeamCity::Test::SimpleFail)])
    ->runtests;

