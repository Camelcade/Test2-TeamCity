use strict;
use warnings;

use lib 't/lib';

# things we use require this, but if we don't have 0.43 or later
# Test2 will complain at us and those complaints pollute our test
# output and cause failure
use Test::Exception 0.43;

use Test2::Require::Module 'Test::Class::Moose' => '0.80';

use T;

run_tests( 't/test-data/Test-Class-Moose', @ARGV );
