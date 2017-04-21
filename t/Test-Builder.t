use strict;
use warnings;

use lib 't/lib';

use T qw( run_tests );

run_tests( 't/test-data/Test-Builder', @ARGV );
