package Test2::Event::TeamCity::StartJob;

use strict;
use warnings;

use parent 'Test2::Event';

use Test2::Util::HashBase qw/name/;

our $VERSION = '1.000000';

1;

__END__

# ABSTRACT: Test Event indicating start of a TeamCity process

=head1 DESCRIPTION

Internal event that allows LTest2::Harness::Renderer::BufferedTeamCity> to
indicate that a job has started and that L<Test2::Formatter::TeamCity> should
react accordingly.

=head2 Attributes

=head3 name

The friendly name of the job that has started as should be reported by
TeamCity.

=head1 SEE ALSO

LTest2::Harness::Renderer::BufferedTeamCity>
L<Test2::Formatter::TeamCity>
