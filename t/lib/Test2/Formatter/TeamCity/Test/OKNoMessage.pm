package Test2::Formatter::TeamCity::Test::OKNoMessage;

use strict;
use warnings;

use Test::Class::Moose;

sub test_method_1 {
    ok 1;
}

1;

__END__

=head1 DESCRIPTION

This class contains one method which in turn calls C<ok> once with no message,
just a boolean indicating success.
