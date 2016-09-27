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
