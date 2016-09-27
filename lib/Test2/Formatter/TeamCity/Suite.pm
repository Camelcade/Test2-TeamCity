package Test2::Formatter::TeamCity::Suite;

use strict;
use warnings;

use Test2::Util::HashBase qw( id name children parent );

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
