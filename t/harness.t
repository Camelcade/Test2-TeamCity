#!/usr/bin/perl

use strict;
use warnings;

# load TestSync, which will set the ENV so our child processes
# know which tempdir to communicate to each other with
use FindBin;
use File::Spec::Functions qw( catdir updir );
use lib catdir( $FindBin::Bin, 'lib' );
use TestSync;

use App::Yath;
use Capture::Tiny qw( capture_merged );
use Path::Class::Rule;
use Test2::Bundle::Extended;
## no critic (BuiltinFunctions::ProhibitStringyEval)
BEGIN { eval 'use Win32::Console::ANSI; 1' or die $@ if 'MSWin32' eq $^O; }
## use critic
use Term::ANSIColor qw(color);

my @t_files
    = map { $_->stringify }
    Path::Class::Rule->new->file->name('*.st')
    ->all( catdir( $FindBin::Bin, 'test-data', 'Harness' ) );

my ($captured) = capture_merged {

    # turn on verbosity.  This will only be printed out if the test suite
    # fails
    local $ENV{TEST2_TEAMCITY_VERBOSE} = 255;

    # fork to avoid App::Yath screwing itself up.  App::Yath doesn't leave
    # the testing framework in a sane state, so when we try to test things
    # after running yath in the same process all hell breaks loose
    my $pid = fork();
    die 'Problem forking' unless defined $pid;
    if ($pid) {
        1 while waitpid( $pid, 0 ) > 0;
        return;
    }

    my $yath = App::Yath->new(
        args => [

            # run all the tests at the same time.  They'll communicate
            # via TestSync's tempdir to ensure that the processes output
            # test events in the same order each time
            '-j', '5',

            # enable our custom renderer (or rather, the testing subclass of
            # it.)  We need to use -q to suppress the standard output.
            '-q',
            '-RTestingBufferedTeamCity',

            # for all the files we found
            '--',
            @t_files
        ],
    );
    $yath->run();
    exit;    # exit child process, parent process will capture our output
};

my $original_output = $captured;

# remove all the non team city lines
my @captured = split /\n/, $captured;
@captured = grep {/##teamcity/} @captured;

# remove everything that is can vary per environment
for (@captured) {
    s/timestamp='[^']+'/timestamp='???'/g;
    s/(Seeded srand with seed) \|'[0-9]+\|'/$1 '???'/g;
    s{\|nat .*t/test-data/Harness/([a-z]+[.]st) line [0-9]+}{|n at $1 line ???}g;
    s/\e\[0m//g;
}
$captured = join "\n", @captured;

my $expected = <<'EXPECTED';
##teamcity[progressMessage 'starting t/harness.t']
##teamcity[testSuiteStarted flowId='t/harness.t' name='t/harness.t' timestamp='???']
##teamcity[testSuiteStarted flowId='t/harness.t' name='script-t/test-data/Harness/first.st' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='one alpha' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='one alpha' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='two bravo' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='two bravo' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='three charlie' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='three charlie' timestamp='???']
##teamcity[testSuiteFinished flowId='t/harness.t' name='script-t/test-data/Harness/first.st' timestamp='???']
##teamcity[testSuiteStarted flowId='t/harness.t' name='script-t/test-data/Harness/second.st' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='four rod' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='four rod' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='five jane' timestamp='???']
##teamcity[testFailed details='Failed test |'five jane|'|n at second.st line ???.|n - this text is sent to STDERR|n - it should be reported as part of the failing test|n' flowId='t/harness.t' message='not ok' name='five jane' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='five jane' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='six freddy' timestamp='???']
##teamcity[message flowId='t/harness.t' text=' - more text is sent to STDERR|n' timestamp='???']
##teamcity[message flowId='t/harness.t' text=' - it should be reported as messages|n' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='six freddy' timestamp='???']
##teamcity[message flowId='t/harness.t' text='Seeded srand with seed '???' from local date.' timestamp='???']
##teamcity[testSuiteFinished flowId='t/harness.t' name='script-t/test-data/Harness/second.st' timestamp='???']
##teamcity[testSuiteStarted flowId='t/harness.t' name='script-t/test-data/Harness/third.st' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='seven bubbles' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='seven bubbles' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='eight buttercup' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='eight buttercup' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='nine blossom' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='nine blossom' timestamp='???']
##teamcity[testSuiteFinished flowId='t/harness.t' name='script-t/test-data/Harness/third.st' timestamp='???']
##teamcity[testSuiteStarted flowId='t/harness.t' name='script-t/test-data/Harness/fourth.st' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='ten fred' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='ten fred' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='eleven barney' timestamp='???']
##teamcity[testFailed details='Failed test |'eleven barney|'|n at fourth.st line ???.|nThis is STDOUT following *a failing test*.  It should be reported as part of|nthe reason the test failed.|n' flowId='t/harness.t' message='not ok' name='eleven barney' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='eleven barney' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='twelve freddy' timestamp='???']
##teamcity[message flowId='t/harness.t' text='This is STDOUT following *a passing test*.  It should be reported as new|n' timestamp='???']
##teamcity[message flowId='t/harness.t' text='messages each time.|n' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='twelve freddy' timestamp='???']
##teamcity[message flowId='t/harness.t' text='Seeded srand with seed '???' from local date.' timestamp='???']
##teamcity[testSuiteFinished flowId='t/harness.t' name='script-t/test-data/Harness/fourth.st' timestamp='???']
##teamcity[testSuiteStarted flowId='t/harness.t' name='script-t/test-data/Harness/fifth.st' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='thirteen twighlight sparkle' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='thirteen twighlight sparkle' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='fourteen pinky pie' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='fourteen pinky pie' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='fifthteen rarity' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='fifthteen rarity' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='sixteen applejack' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='sixteen applejack' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='seventeen rainbow dash' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='seventeen rainbow dash' timestamp='???']
##teamcity[testStarted flowId='t/harness.t' name='eighteen fluttershy' timestamp='???']
##teamcity[testFinished flowId='t/harness.t' name='eighteen fluttershy' timestamp='???']
##teamcity[testSuiteFinished flowId='t/harness.t' name='script-t/test-data/Harness/fifth.st' timestamp='???']
##teamcity[testSuiteFinished flowId='t/harness.t' name='t/harness.t' timestamp='???']
EXPECTED
chomp $expected;

unless ( ok( $captured eq $expected, 'output matches expected' ) ) {
    diag('***** Strings differ *****');

    ( $captured, $expected ) = colorize_differences( $captured, $expected );

    diag( "output is:\n" . "$captured\nnot:\n$expected\nas expected" );
    diag('***** With Debugging *****');
    diag($original_output);
}

done_testing();

# code taken from Test::Builder::Tester to colorize
# copyright Mark Fowler 2002, 2004.  Used with permission, obviously ;-)
sub colorize_differences {
    my $got    = shift;
    my $wanted = shift;

    # colors
    my $green = color('black') . color('on_green');
    my $red   = color('black') . color('on_red');
    my $reset = color('reset');

    # work out where the two strings start to differ
    my $char = 0;
    $char++ while substr( $got, $char, 1 ) eq substr( $wanted, $char, 1 );

    # get the start string and the two end strings
    my $start = $green . substr( $wanted, 0, $char );
    my $gotend    = $red . substr( $got,    $char ) . $reset;
    my $wantedend = $red . substr( $wanted, $char ) . $reset;

    # make the start turn green on and off
    $start =~ s/\n/$reset\n$green/g;

    # make the ends turn red on and off
    $gotend =~ s/\n/$reset\n$red/g;
    $wantedend =~ s/\n/$reset\n$red/g;

    # rebuild the strings
    $got    = $start . $gotend;
    $wanted = $start . $wantedend;

    return ( $got, $wanted );
}
