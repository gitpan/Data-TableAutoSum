#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;
use Data::TableAutoSum;
use List::Util qw/sum/;

use constant LITTLE_TABLE => join "\n", "\t0\tSum",
                                        "0\t42\t42",
                                        "Sum\t42\t42\n";
                                        
use constant MAGIC_SQUARE => join "\n", "\t0\t1\t2\tSum",
                                        "0\t2\t9\t4\t15",
                                        "1\t7\t5\t3\t15",
                                        "2\t6\t1\t8\t15",
                                        "Sum\t15\t15\t15\t45\n";

use constant RECIPROKES   => map({1/$_} (1 .. 10));                                         
use constant ONE_ROW => join "\n", (join "\t", "", 0 .. 9, "Sum"),
                                   (join "\t", 0, RECIPROKES, sum RECIPROKES),
                                   (join "\t", "Sum", RECIPROKES, sum RECIPROKES),
                                   "";

for (Data::TableAutoSum->new(rows => 1, cols => 1)) {
    $_->data(0,0) = 42;
    is $_->as_string, LITTLE_TABLE, "1x1 table as string";
}

sub qt($) {
    $_ = shift();
    s/\t/\\t\t/g;
    s/\n/\\n\n/g;
    return $_;
}

for (Data::TableAutoSum->new(rows => 3, cols => 3)) {
    $_->data(0,0) = 2;  $_->data(0,1) = 9;  $_->data(0,2) = 4;
    $_->data(1,0) = 7;  $_->data(1,1) = 5;  $_->data(1,2) = 3;
    $_->data(2,0) = 6;  $_->data(2,1) = 1;  $_->data(2,2) = 8;
    is qt $_->as_string, qt MAGIC_SQUARE, "3x3 table as string";
}


for (Data::TableAutoSum->new(rows => 1, cols => scalar(RECIPROKES))) {
    for my $i (0 .. scalar(RECIPROKES)-1) {
        $_->data(0,$i) = 1/($i+1);
    }
    is qt $_->as_string, qt ONE_ROW, "1x10 table as string";
}
