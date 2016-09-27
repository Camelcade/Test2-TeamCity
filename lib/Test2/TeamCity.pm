package Test2::TeamCity;

use strict;
use warnings;

use Test2::API qw( context );
use Test2::Event::TeamCity::Message;

use Exporter qw( import );

our @EXPORT_OK = 'tc_message';

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
