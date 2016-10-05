package Test2::Formatter::TeamCity::Test::OKNoMessage;

use strict;
use warnings;

use Test::Class::Moose;

sub test_method_1 {
    ok 1;
}

1;

# ABSTRACT: An example test suite class for testing Test2::TeamCity

__END__

=head1 DESCRIPTION

Class used for testing simple success message that B<doesn't have a tap
message associated with it.>
