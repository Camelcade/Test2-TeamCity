package    # hide from PAUSE
    T;

use strict;
use warnings;

use IPC::Run3 qw(run3);
use Path::Class::Rule;
use Path::Class;
use Test2 1.0203060 ();
use Test2::Bundle::Extended;
use Test::Class::Moose 0.80 ();

use Exporter qw( import );

our @EXPORT = 'run_tests';

sub run_tests {
    my $dir  = shift;
    my @args = @_;

    my @tests
        = @args
        ? map { m{^t/} ? $_ : "$dir/$_" } @args
        : glob "$dir/*";

    _test_formatter($_) for @tests;

    done_testing;
}

sub _test_formatter {
    my $test_dir = shift;

    subtest(
        $test_dir,
        sub {
            my @t_files
                = Path::Class::Rule->new->file->name('input.st')->all($test_dir)
                or return;

            if ( @t_files > 1 ) {
                die "Cannot run more than once test file ($test_dir)";
            }

            my ( @stdout, @stderr );
            {
                local $ENV{T2_FORMATTER} = 'TeamCity';
                run3(
                    [ $^X, qw( -I lib ), @t_files ],
                    \undef,
                    \@stdout,
                    \@stderr,
                );
            }

            if ( $ENV{TEST_VERBOSE} ) {
                note('---- Start TC messages ----');
                note(@stdout);
                note('---- End TC messages ----');
            }

            my $munged = join q{}, map { _remove_timestamp($_) } @stdout;
            my $stderr = join q{}, @stderr;
            _test_output( $t_files[0], $munged, $stderr );
        }
    );
}

sub _remove_timestamp {
    my $line = shift;

    # We only touch TC message lines that include name/value pairs
    return $line unless $line =~ /^\Q##teamcity[\E[^ ]+ [^=]+='[^']*'/;

    my $ok = ok(
        $line =~ s/ timestamp='([^']+)'//,
        'teamcity directive line has a timestamp'
    ) or diag($line);

    if ($ok) {
        my $ts = $1;
        like(
            $ts,
            qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/,
            'timestamp matches expected format'
        );
    }

    return $line;
}

sub _test_output {
    my $t_file = shift;
    my $stdout = shift;
    my $stderr = shift;

    subtest( 'stdout', sub { _test_stdout( $t_file, $stdout ) } );
    subtest( 'stderr', sub { _test_stderr( $t_file, $stderr ) } );

    return;
}

sub _test_stdout {
    my $t_file = shift;
    my $stdout = shift;

    my $stdout_file = $t_file->dir->file('stdout.txt');

    my $expected
        = -e $stdout_file
        ? scalar $stdout_file->slurp
        : undef;

    if ( defined $expected ) {
        $stdout
            =~ s{\QSeeded srand with seed |'\E\d{8}\Q|' from local date.}
                {Seeded srand with seed |'{DATE}|' from local date.};

        # This hacks exist to replace user-specific paths with some sort of
        # fixed test.
        s{\|nat .+?/AsyncSubtest[.]pm line \d+}{\|nat CODE line XXX}g
            for ($stdout, $expected);

        _compare_lines( $stdout, $expected )
            or diag($stdout);
    }
    else {
        ok( $stdout eq q{}, 'stdout is empty' )
            or diag($stdout);
    }

    return;
}

sub _test_stderr {
    my $t_file = shift;
    my $stderr = shift;

    my $stderr_file = $t_file->dir->file('stderr.txt');

    my $expected
        = -e $stderr_file
        ? scalar $stderr_file->slurp
        : undef;

    if ( defined $expected ) {
        _clean_traces( \$stderr );
        _clean_subtest_ids( \$stderr );
        _clean_file_references( \$stderr, \$expected );
        _clean_module_load_errors( \$expected );

        _compare_lines( $stderr, $expected )
            or diag($stderr);
    }
    else {
        ok( $stderr eq q{}, 'stderr is empty' )
            or diag($stderr);
    }
}

sub _compare_lines {
    my $got      = shift;
    my $expected = shift;

    # This splits on lines without stripping out the newline.
    my @got = split /(?<=\n)/, ( $got // q{} );
    my @expected = split /(?<=\n)/, $expected;

    return is(
        \@got,
        array {
            item $_ for @expected;
            end();
        },
        'got expected output'
    );
}

sub _clean_traces {
    my $got = shift;

    # These are traces that Test2 outputs when tests exit or die mid-stream
    # with an unreleased context. We don't care exactly where it reports these
    # from.
    ${$got} =~ s/^(\s+File:\s+).+$/$1\{FILE}/mg;
    ${$got} =~ s/^(\s+Line:\s+).+$/$1\{LINE}/mg;
    ${$got} =~ s/^(\s+Tool:\s+).+$/$1\{TOOL}/mg;

    return;
}

sub _clean_subtest_ids {
    my $got = shift;

    ${$got}
        =~ s/Last suite on the stack \(\d+-\d+-\d+\)/Last suite on the stack ({SUBTEST-ID})/;

    return;
}

sub _clean_file_references {
    # These hacks exist to replace user-specific paths with some sort of fixed
    # test.
    for my $output (@_) {
        ${$output}
            =~ s{(#\s+at ).+/Moose([^\s]+) line \d+}{${1}CODE line XXX}g;
        ${$output}
            =~ s{ at .+?/AsyncSubtest[.]pm line \d+}{ at CODE line XXX}g;
        ${$output} =~ s{\(\@INC contains: .+?\)}{(\@INC contains: XXX)}sg;
    }

    return;
}

sub _clean_module_load_errors {
    my $expected = shift;

    # The error message for attempting to load a module that doesn't exist was
    # changed in 5.18.0.
    ${$expected}
        =~ s{\Q(you may need to install the SomeNoneExistingModule module) }{}g
        if $] < 5.018;

    return;
}

1;

__END__

=head1 SYNOPSIS

  use T;
  run_tests('t/test-data/Test-Builder');

=head2 DESCRIPTION

The universal test runner for testing the Test2::TeamCity formatter.

The file structure should be something like:

    t/test-data/
        test-name-here/
            test-case-1/
                input.st
                stdout.txt
            test-case-explosion/
                input.st
                stdout.txt
                stderr.txt
            yet_another_directory/
                input.st
                stdout.txt

The C<input.st> code should contain Perl code that executes Perl tests using
either old-style Perl tools like L<Test::More> or the L<Test2> tools.

The C<stdout.txt> should contain TeamCity style output that the Perl code when
executed with the Test2::TeamCity::Formatter should produce. The C<stderr.txt>
file contains the output that is expected to go to stderr. Either file can be
ommitted, in which case the test makes sure that the appropriate filehandle
receives no output.

If you set the C<TEST_VERBOSE> env var to true, then this test code will use
C<note> to display the stdout output that was actually received.

=head1 FUNCTIONS

This module provides one function which is exported by default.

=head3 run_tests($dir)

This looks through the given directory recursively for subdirectories
containing C<input.st> files. It runs them and compares them to the output
file in the same directory.

