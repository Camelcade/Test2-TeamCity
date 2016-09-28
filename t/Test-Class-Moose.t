use strict;
use warnings;

use lib 't/lib';

use Test2::Require::Module 'Test::Class::Moose' => '0.80';

use T;

run_tests( 't/test-data/Test-Class-Moose', @ARGV );
