package Test2::Event::TeamCity::Message;

use strict;
use warnings;

use parent 'Test2::Event';

use Test2::Util::HashBase qw/status text/;

sub init {
    my $self = shift;

    $self->{+STATUS} ||= 'NORMAL';

    return;
}

1;

# ABSTRACT: A TeamCity message event

__END__

=head1 DESCRIPTION

This is a L<Test2::Event> representing an explicit TeamCity message being
sent.

=head1 ACCESSORS

This class provides the following accessors:

=head2 status

The message's status. This defaults to C<NORMAL>. It can be any status allowed
by TeamCity.

=head2 text

The text of the message.
