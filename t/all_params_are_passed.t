#!/usr/bin/perl

use strict;
use warnings;

use Test::ManyParams;
use Test::More tests => 2 * 4;
use Data::Dumper;
$Data::Dumper::Indent = undef;

sub knows_all_arguments {
    my %exp_numbers = map {$_ => 1} @{shift()};
    my $params   = shift;
    all_ok { $_ = join "", @_; 
             exists $exp_numbers{$_} and delete $exp_numbers{$_} 
    } $params,
      "All params passed to the check routines are known " .
      "and there's no param tuple used twice (" . Dumper($params) . ")";
    ok( (scalar keys %exp_numbers) == 0,
       "All params that should have passed, had been passed" .
       " (" .  Dumper($params) . ")" )
    or diag "These numbers weren't passed: ", sort {$a <=> $b} keys %exp_numbers;
}

knows_all_arguments(reverse @$_) for (
    [ [1 .. 10]                                => [1 .. 10] ],
    [ [[1 .. 10]]                              => [1 .. 10] ],
    [ [[1 .. 9], [1 .. 9]]                     => [grep !/0/, (11 .. 99)] ], 
    [ [[1 .. 9], [1 .. 9], [1 .. 9]]           => [grep !/0/, (111 .. 999)] ]
);
