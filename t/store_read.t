#!/usr/bin/perl

use strict;
use warnings;

use Data::TableAutoSum;
use Test::More;
use Test::Exception;
use Math::Random qw/:all/;
use t'CommonStuff;

use constant TEMP_FILE => 'store_read.table';


sub test_store_read {
    my %dim = @_;
    my $orig = Data::TableAutoSum->new(%dim);
    $orig->store(TEMP_FILE);  # print an empty table
    
    foreach my $row ($orig->rows) {
        foreach my $col ($orig->cols) {
            $orig->data($row,$col) = sprintf "%.2f",   # only some rounding for fix point calculation
                                     random_uniform(1, -1_000_000, +1_000_000);
        }
    }
    
    my $DxD = $dim{rows} . "x" . $dim{cols} . " table";
    
    my $ret_value = $orig->store(TEMP_FILE);
    ok $ret_value == $orig, "->store method returns the object itselfs ($DxD)";
    open STORED_TABLE, '<', TEMP_FILE or die "Can't open the stored table: $!";
    my $stored_table = join "", (<STORED_TABLE>);
    close STORED_TALE;
    is $stored_table, $orig->as_string, 
       "Stored table looks like the as_string representation ($DxD)";
    
    my $copy = Data::TableAutoSum->read(TEMP_FILE);
    is $copy->as_string, $orig->as_string,
       "Read stored table has the same as_string represantion as the original ($DxD)";
}

use Test::More tests => 3 * STANDARD_DIM + 2;
test_store_read( rows => $_->[0], cols => $_->[1] ) for STANDARD_DIM;

throws_ok {Data::TableAutoSum->new(rows => 1, cols => 1)->store()}
          qr/can't open/i,
          "store without a filename";
          
throws_ok {Data::TableAutoSum->read()}
          qr/can't open/i,
          "read without a filename";         
