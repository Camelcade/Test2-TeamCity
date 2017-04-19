use strict;
use warnings;

use lib 't/lib';

use T qw( run_tests );

# setting this makes the tests pass
local $ENV{HARNESS_ACTIVE} = undef;

run_tests( 't/test-data/Test2', @ARGV );
