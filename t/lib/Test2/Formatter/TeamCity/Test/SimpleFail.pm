package Test2::Formatter::TeamCity::Test::SimpleFail;

use strict;
use warnings;

use Test::Class::Moose;

sub test_method_1 {
    ok 0, 'tcm-method-1-test-1';
    ok 1, 'tcm-method-1-test-2';
}

sub test_method_2 {
    ok 1, 'tcm-method-2-test-1';
    ok 0, 'tcm-method-2-test-2';
}

1;

# ABSTRACT: An example test suite class for testing Test2::TeamCity

__END__

=head1 DESCRIPTION

Class used for testing success and failure methods messages.

This class simply has two methods C<test_method_1> and C<test_method_2>
that produce one failure, one success each (though in different orders.)
