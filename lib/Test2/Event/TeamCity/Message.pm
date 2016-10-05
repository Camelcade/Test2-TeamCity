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

# ABSTRACT a TeamCity message event

__END__

=head2 Attributes

=head3 status

The status.  Defaults to C<NORMAL>

=head3 text

The text of the message
