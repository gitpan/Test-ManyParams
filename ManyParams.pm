package Test::ManyParams;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
    all_ok	
    all_are all_arent
);

our $VERSION = '0.02';

use Test::Builder;
use Set::CrossProduct;
use Data::Dumper;

my $Tester = Test::Builder->new();

sub does_all {
    my ($sub, $params) = @_;
    my $failed_param = undef;
    if (ref($params->[0]) eq 'ARRAY') {
        if (grep {ref($params->[$_]) ne 'ARRAY'} (1 .. @$params-1)) {
            die "If the first parameter is an arrayref, all other parameters must be also. " .
                "Called with Parameter-Ref: " . _dump_params($params);
        }
        $failed_param = @$params > 1
            ? _try_all_of_xproduct($sub, Set::CrossProduct->new( $params ))
            : _try_all_of_the_list($sub, @{$params->[0]});
    } else {
        $failed_param = _try_all_of_the_list($sub, @$params);
    }
    my $ok = not defined($failed_param);
    my @diag = $ok 
        ? () 
        : ("Tests with the parameters: " . _dump_params($params),
           "Failed first using these parameters: " . _dump_params($failed_param));
    return ($ok, @diag);
}

sub all_ok(&$;$) {
    my ($sub, $params, $test_name) = @_;
    my ($ok, @diag) = does_all(@_);
    $Tester->ok( $ok, $test_name ) or do { $Tester->diag($_) for @diag };
    return $ok;
}

sub all_are(&$$;$) {
    my ($sub, $expected, $params, $test_name) = @_;
    my $found = undef;
    my ($ok, @diag) = 
        does_all( sub { $found = $sub->(@_); $found eq $expected }, $params);
    $Tester->ok($ok, $test_name)
    or do {
        $Tester->diag($_) for @diag;
        $Tester->diag("Expected: " . _dump_params($expected));
        $Tester->diag("but found: " . _dump_params($found));
    };
}

sub all_arent(&$$;$) {
    my ($sub, $unexpected, $params, $test_name) = @_;
    my $found = undef;
    my ($ok, @diag) = 
        does_all( sub { $found = $sub->(@_); $found ne $unexpected }, $params);
    $Tester->ok($ok, $test_name)
    or do {
        $Tester->diag($_) for @diag;
        $Tester->diag("Expected not to find " . _dump_params($unexpected) . " but found it");
    };
}

sub _try_all_of_the_list {
    my ($sub, @param) = @_;
    foreach my $p (@param) {
        $sub->($p) or return [$p];
    }
    return undef;
}

sub _try_all_of_xproduct {
    my ($sub, $iterator) = @_;
    my $tuple = undef;
    while ($tuple = $iterator->get()) {
        $sub->(@$tuple) or last;
    }
    return $tuple;
}

sub _dump_params {
    local $_ = Dumper($_[0]);
    s/\s+//gs;   # remove all indents, but I didn't want to set 
                 # $Data::Dumper::Indent as it could have global effects
    s/^.*? = //; # remove the variable name of the dumped output
    return $_;
}


1;

__END__
=head1 NAME

Test::ManyParams - module to test many params as one test

=head1 SYNOPSIS

  use Test::ManyParams;

  all_ok {foo(@_)}  
         [ [$arg1a, $arg2a], [$arg2b, $arg2b, $arg3b, $arg4b] ],
         "Testing that foo returns true for every combination of the arguments";
         
  all_ok {bar(shift())}
         [qw/arg1 arg2 arg3 arg4 arg5 arg6/],
         "Testing every argument with bar";
         
  all_are       CODE  VALUE,   PARAMETERS, [ TEST_NAME ]
  all_arent     CODE  VALUE,   PARAMETERS, [ TEST_NAME ]
  
  [NOT YET IMPLEMENTED]
  
  all_are_deeply  CODE  SCALAR,  PARAMETERS, [ TEST_NAME ]
  all_like        CODE  REGEXP,  PARAMETERS, [ TEST_NAME ]
  all_unlike      CODE  REGEXP,  PARAMETERS, [ TEST_NAME ]
  all_can         CODE  METHODS, PARAMETERS, [ TEST_NAME ]
  all_dies_ok     CODE           PARAMETERS, [TEST_NAME]
  all_lives_ok    CODE           PARAMETERS, [TEST_NAME]
  all_throws_ok   CODE  REGEXP,  PARAMETERS, [TEST_NAME]

=head1 DESCRIPTION

=head2 GENERAL PRINCIPLES

This module helps to tests many parameters at once.
In general, it calls the given subroutine with every
combination of the given parameter values.
The combinations are created with building a cross product.

Especially it avoids writing ugly, boring code like:

  my $ok = 1;
  foreach my $x ($arg1a, $arg2a) {
      foreach my $y ($arg2a, $arg2b, $arg3b, $arg4b) {
          $ok &&= foo($x,$y);
      }
  }
  ok $ok, $testname;
  
Instead you simpler write

  all_ok {foo(@_)}  
         [ [$arg1a, $arg2a], [$arg2b, $arg2b, $arg3b, $arg4b] ]
         $testname;
  
Additionally the output contains also some useful information
about the parameters that should be tested and the first parameters the
test failed. E.g.

  all_ok {$_[0] != 13 and $_[1] != 13} 
         [ [1 .. 100], [1 .. 100] ], 
         "No double bad luck";
         
would print:

  not ok 1 - No double bad luck
  #     Failed test (x.pl at line 5)
  # Tests with the parameters: $VAR1=[[10,11,12,13,14,15],[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]];
  # Failed first using these parameters: $VAR1=[10,13];
  
  
The parameters passed to C<all_ok> can be passed in two ways.
If you need to test a crossproduct of more than one parameterlist,
you have to write it as

  all_ok CODE [ \@arglist1, \@arglist2, ..., \@arglistn ], TEST_NAME;
  
The CODE-routine will be called with every combination of the arglists,
passed as simple arguments. E.g.

  all_ok {foo(@_)} [ ["red", "green", "blue"], ["big", "medium", "little"] ];
  
would call

  foo("red","big");
  foo("red","medium");
  foo("red","little");
  foo("green","big");
  foo("green","medium");
  foo("green","little");
  foo("blue","big");
  foo("blue","medium");
  foo("blue","little");

Note, that the order of calling shouldn't play any role,
as it could be changed in future versions without any notice about.

Please always remember, that a crossproduct of the lists can be very, very big.
So don't write something like 
C<all_ok {&foo} [ [1 .. 32000], [1 .. 32000], [1 .. 32000] ]>,
as it would test 32_768_000_000_000 parameter combinations.

If you only want to test one parameter with different values,
you can write in general

  all_ok CODE \@values, TEST_NAME
 
So C<all_ok {&foo} [1,2,3]> would call C<foo(1); foo(2); foo(3)>.

Please take care, that the first element of the values list isn't an array ref,
as Test::ManyParams would assume that you want to test combinations of the above.
If it is important to pass values that are array refs,
you have to write it this way:

  my @values = ( [1 .. 10],
                 [100 .. 110],
                 [990 .. 1000] );
  all_ok {&foo} [ [@values] ];
  
  # calls foo(1), ... foo(10), foo(100), ..., foo(110), foo(990), ..., foo(1000)
  
what is very different to

  all_ok {&foo} [ @values ];
  
  # what would call foo(1,100,900), foo(1,100,901), ...
  

Of course, the test name is always optional, but recommended.

=head2 FUNCTIONS

=over

=item all_ok  CODE  PARAMETERS,  [ TEST_NAME ]

See the general comments.

=item all_are  CODE  VALUE,  PARAMETERS,  [ TEST_NAME ]

The equivalent to C<Test::More>'s C<is> method.
The given subroutine has to return always the given value.
They are compared with 'eq'.

=item all_arent  CODE  VALUE,  PARAMETERS,  [ TEST_NAME ]

The equivalent to C<Test::More>'s C<isnt> method.
The given subroutine has to return always values different from the given one.
They are compared with 'eq'.

=back


=head2 EXPORT

C<all_ok>
C<all_are>
C<all_arent>

=head1 BUGS

The representation of the parameters uses Data::Dumper.
As this module neither set $Data::Dumper::Indent,
nor reads it out,
setting $Data::Dumper::Indent to some strange values
can destroy a useful parameter outprint.
I don't plan to fix this behaviour in the next time,
as I there a more important things to do.
(Who changes global variables harvest what he/she/it has seed.)

There are perhaps many mistakes in this documentation.

Please tell me everything you can find.

=head1 TODO

There are a lot of methods I'd like to implement still.
The most of them are simple 
Here's a list of them:

=over

=item all_are_deeply  CODE  SCALAR,  PARAMETERS, [ TEST_NAME ]

=item all_like CODE  REGEXP, PARAMETERS, [ TEST_NAME ]

=item all_unlike CODE  REGEXP, PARAMETERS, [ TEST_NAME ]

=item all_can CODE  REGEXP, PARAMETERS, [ TEST_NAME ]

=item all_dies_ok CODE  PARAMETERS, [TEST_NAME]

=item all_lives_ok CODE  PARAMETERS, [TEST_NAME]

=item all_throws_ok CODE  REGEXP, PARAMETERS, [TEST_NAME]

=back

Then I'd like to implement a method that uses only some random
choosen parameters instead of all parameters.

That is important when the parameter set is too big to
have a full test of on them.

This method will look like

  most_ok CODE  PARAMETERS  =>  PART,  [TEST_NAME]
  
where the PART is something like a normal number,
defining the number of parameters that have to be tested,
or a percentage rate or a time rate.
Also an addition to say that all bounds have to be tested is planned.
Typical examples for PART could be C<'1000', '1%', '5s', '100 + bounds'>.

The pro and contra of had been discussed a bit on perl.qa.
One of the results is that random parameter tests are very sensful,
but the reproducibility is very important.
So the module has to seed (or recognise the seed) of the random generator
and to give the possibility to set them
(e.g. with C<use Test::ManyParams seed => 42>).
Recognising a failed test, this seed has to be printed.
It always seems to be sensful to set an own random numbering for each package
using this module.

That's only a short synopsis of this discussion,
it will be better explained when these features are built in.

Of course, there will be also some methods like C<most_are>,C<most_arent>,... .


The next thing, I'll do is to implement the C<all_dies_ok> method.


=head1 SEE ALSO

This module had been and will be discussed on perl.qa.

L<Test::More>
L<Test::Exception>

=head1 THANKS

Thanks to Nicholas Clark and to Tels (http://www.bloodgate.com) for
giving a lot of constructive ideas.

=head1 AUTHOR

Janek Schleicher, E<lt>bigj@kamelfreund.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Janek Schleicher

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
