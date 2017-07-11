#!/bin/sh

export PERL5LIB="../lib"

yath -j 2 -q -RBufferedTeamCity \
    tests/batman.t \
    tests/smurfs.t
