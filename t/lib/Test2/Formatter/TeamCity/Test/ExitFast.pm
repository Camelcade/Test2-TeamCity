package Test2::Formatter::TeamCity::Test::ExitFast;

use strict;
use warnings;

use Test::Class::Moose;

sub test_method_1 {
    exit;
    ## no critic (ControlStructures::ProhibitUnreachableCode)
    ok 1, 'tcm-method-1';
}

1;

__END__

=head1 DESCRIPTION

This class has one method that exits prematurely by calling C<exit> before
actually running any test functions.
