package Test2::Formatter::TeamCity::Suite;

use strict;
use warnings;

use Test2::Util::HashBase qw( id name children parent );

our $VERSION = '1.000000';

sub init {
    my $self = shift;

    $self->{ +CHILDREN } = [];

    return;
}

sub add_child {
    my $self = shift;

    push @{ $self->{ +CHILDREN } }, shift;

    return;
}

1;

__END__

# ABSTRACT: Test2 formatter for TeamCity helper object for test suites

=head1 DESCRIPTION

Internal object used by the Test2::Formatter::TeamCity to represent a test suite

=head2 Attributes

=head3 id

Test suite id

=head3 name

Test suite name

=head3 children

Array of child tests

=head3 parent

Parent test suite

=head3 Methods

=head3 $test_suite->add_child( $child )

Add to the array of children

=for Pod::Coverage
    init
