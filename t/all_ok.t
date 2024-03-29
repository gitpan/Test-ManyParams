#!/usr/bin/perl

use strict;
use warnings;

use Test::ManyParams;
use Test::More;
use Test::Exception;
use Test::Builder::Tester tests => 239;
use Data::Dumper;
use t::CommonStuff;

Test::Builder::Tester::color(1);

sub always_true_is_always_true($;$) {
    my ($params, $testname) = @_;
    test_out "ok 1" . ($testname ? " - $testname" : "");
    $testname ? all_ok { 1 } $params, $testname : all_ok { 1 } $params;
    test_test "Everything should be O.K., if sub always returns true ".
              _dump_params({params => $params, testname => $testname});
}

sub fails_at_a_value($$;$) {
    my ($params, $fail_params, $testname) = @_;
    test_out "not ok 1" . ($testname ? " - $testname" : "");
    test_fail +3;
    test_diag "Tests with the parameters: " . _dump_params($params);
    test_diag "Failed first using these parameters: " . _dump_params($fail_params);
    all_ok { ! eq_array \@_, $fail_params } $params, $testname;
    test_test "all_ok should fail" .
              _dump_params({params => $params, fail => $fail_params, testname => $testname});
}

foreach (STANDARD_PARAMETERS()) {
    my ($params, $values) = @$_;
    always_true_is_always_true $params;
    always_true_is_always_true $params, "With any testname";
    foreach (@$values) {
        my $fail_params = [split //];
        fails_at_a_value $params, $fail_params;
        fails_at_a_value $params, $fail_params, "With a testname";
    }
}

dies_ok { all_ok { 1 } [ [1 .. 10], 11, 12, 13 ] }
        "Used a an array of arrays and not-arrays, what's not ok and should die";
