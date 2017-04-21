package Test2::TeamCity;

use strict;
use warnings;

use Test2::API 1.302083 qw( context );
use Test2::Event::TeamCity::Message;

use Exporter qw( import );

our @EXPORT_OK = 'tc_message';

our $VERSION = '1.000000';

sub tc_message {
    my ( $status, $text );
    if ( @_ == 2 ) {
        $status = shift;
        $text   = shift;
    }
    elsif ( @_ == 1 ) {
        $text = shift;
    }
    else {
        die 'Too many arguments for tc_message()';
    }

    my $ctx = context();
    $ctx->send_event(
        'TeamCity::Message',
        text => $text,
        ( $status ? ( status => $status ) : () ),
    );
    $ctx->release;

    return;
}

1;

# ABSTRACT: TeamCity tools for Test2

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::TeamCity - TeamCity tools for Test2

=head1 VERSION

version 1.000000

=head1 DESCRIPTION

=head2 Exported Functions

=head3 tc_message( $status, $text )

Send a TeamCity::Message event by the Test2 API

=head1 SUPPORT

Bugs may be submitted at L<https://github.com/maxmind/Test2-TeamCity/issues>.

=head1 SOURCE

The source code repository for Test2-Formatter-TeamCity can be found at L<https://github.com/maxmind/Test2-TeamCity>.

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by MaxMind, Inc..

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

The full text of the license can be found in the
F<LICENSE> file included with this distribution.

=cut
