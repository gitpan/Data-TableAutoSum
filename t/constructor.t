#!/usr/bin/perl -w

use strict;

use Data::TableAutoSum;
use List::Util qw/sum/;
use Test::More;
use t'CommonStuff;

sub test_construct_table {
    my %dim = @_;
    my $table = Data::TableAutoSum->new(rows => $dim{rows}, cols => $dim{cols});
    ok eq_array [$table->rows()], [0 .. $dim{rows}-1], "rows after construction";
    ok eq_array [$table->cols()], [0 .. $dim{cols}-1], "cols after construction";
    TEST_DIMENSION: {
        my $r = $table->rows;
        my $c = $table->cols;
        is $r, $dim{rows}, "nr of rows after construction";
        is $c, $dim{cols}, "nr of cols after construction";
    }
    all_ok {$table->data(@_) == 0}
           [[$table->rows], [$table->cols]],
           "data(row,col) == 0 after construction";
    all_ok {$table->rowresult(shift()) == 0}
           [$table->rows],
           "rowresult == 0 after construction";
    all_ok {$table->colresult(shift()) == 0}
           [$table->cols],
           "colresult == 0 after construction";
    is $table->totalresult, 0, "totalresult after construction";
}

use constant STANDARD_DIM_TESTS => 8 * scalar(STANDARD_DIM());
    
use constant WRONG_NEW_PARAMS => ({},
                                  {rows => 10},
                                  {cols => 10},
                                  {rows =>  0, cols => 10},
                                  {rows => 10, cols =>  0},
                                  {rows =>  0, cols =>  0},
                                  {10, 10},
                                  {rows => "ten", cols => "ten"});
use constant WRONG_NEW_PARAMS_TESTS => scalar WRONG_NEW_PARAMS;

use Test::More tests => STANDARD_DIM_TESTS + WRONG_NEW_PARAMS_TESTS;
use Test::Exception;

test_construct_table(rows => $_->[0], cols => $_->[1]) for STANDARD_DIM;
foreach (WRONG_NEW_PARAMS) {
    dies_ok {Data::TableAutoSum->new(%$_)} "new(".(%$_).")";
}
