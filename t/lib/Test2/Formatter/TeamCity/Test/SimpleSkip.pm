package Test2::Formatter::TeamCity::Test::SimpleSkip;

use strict;
use warnings;

use Test::Class::Moose;

sub test_setup {
    my ( $test, $report ) = @_;
    if ( 'test_method_1' eq $report->name ) {
        $test->test_skip(q{"the reason for skipping test_method_1"});
    }
}

sub test_method_1 {
    ok 1, 'tcm-method-1-test-1';
}

sub test_method_2 {
    ok 1, 'tcm-method-2-test-1';
}

1;

__END__

=head1 DESCRIPTION

This class simply has two methods, C<test_method_1> and
C<test_method_2>. However, the call to C<test_method_1> will be skipped using
the C<test_setup> method. The C<test_method_2> method contains one call to
C<ok> with a true value.
