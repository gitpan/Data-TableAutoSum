#!/usr/bin/perl -w

use strict;

use Data::TableAutoSum;
use List::Util qw/sum/;
use Math::Random qw/:all/;
use Set::CrossProduct;
use Test::More;
use Test::Exception;
use t'CommonStuff;

sub test_results {
    my $table = Data::TableAutoSum->new(@_);
    my $totalsum = 0;
    foreach my $row ($table->rows) {
        foreach my $col ($table->cols) {
            $totalsum +=
                 $table->data($row,$col) = random_uniform(1, -10_000, +10_000);
        }
    }
    all_ok {
        my $row = shift(); 
        $table->rowresult($row) == sum(map {$table->data($row,$_)} $table->cols)
    } [$table->rows], "rowresult";
    all_ok {
        my $col = shift(); 
        $table->colresult($col) == sum(map {$table->data($_,$col)} $table->rows)
    } [$table->cols], "colresult";
    is $table->totalresult, $totalsum, "totalresult";
}

use constant RESULT_TESTS => 3 * STANDARD_DIM;

use Test::More tests => RESULT_TESTS;

test_results( rows => $_->[0], cols => $_->[1] ) for STANDARD_DIM;
