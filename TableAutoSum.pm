package Data::TableAutoSum;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# I export nothing, so there aren't any @EXPORT* declarations

our $VERSION = '0.02';

use Params::Validate qw/:all/;
use Regexp::Common;
use Set::Scalar;
use List::Util qw/reduce/;

use constant ROW_COL_TYPE => {
    type      => SCALAR,
    callbacks =>  {'integer'        => sub { shift() =~ $RE{num}{int} },
                   'greater than 0' => sub { shift() > 0 }}
};

sub new {
    my $proto = shift;
    my %arg = validate( @_ => {rows => ROW_COL_TYPE, cols => ROW_COL_TYPE} );
    my $class = ref($proto) || $proto;
    my @rows = (0 .. $arg{rows}-1);
    my @cols = (0 .. $arg{cols}-1);
    my $self = {
        rows   => \@rows,
        rowset => Set::Scalar->new(@rows),
        cols   => \@cols,
        colset => Set::Scalar->new(@cols),
        data   => [map [(0) x $arg{cols}], 0..$arg{rows}]
    };
    $self->{rowset} = Set::Scalar->new(@{$self->{rows}});
    bless $self, $class;
}

sub rows {
    my $self = shift;
    return @{$self->{rows}};
}

sub cols {
    my $self = shift;
    return @{$self->{cols}};
}

sub data : lvalue {
    my $self = shift; 
    my ($row, $col, $value) = validate_pos( @_,
        {type => SCALAR,
         callbacks => {'is a row' => sub {$self->{rowset}->contains(shift())}}
        },
        {type => SCALAR,
         callbacks => {'is a col' => sub {$self->{colset}->contains(shift())}}
        },
        0
    );
    $self->{data}->[$row]->[$col] = $value if defined $value;
    $self->{data}->[$row]->[$col];
}

sub as_string {
    my $self = shift;
    my $output = join "\t", "", $self->cols, "Sum\n";
    foreach my $row ($self->rows) {
        $output .= $row . "\t";
        $output .= join "\t", map {$self->data($row,$_)} ($self->cols);
        $output .= "\t" . $self->rowresult($row) . "\n";
    }
    $output .= join "\t", "Sum", map {$self->colresult($_)} $self->cols;
    $output .= "\t" . $self->totalresult . "\n";
    return $output;
}

sub _calc_data {
    my $result = $_[0];
    $result += $_[$_] for (1 .. $#_);
    return $result;
}

sub rowresult {
    my ($self, $row) = @_;
    return _calc_data( map {$self->data($row,$_)} $self->cols );
}

sub colresult {
    my ($self, $col) = @_;
    return _calc_data( map {$self->data($_,$col)} $self->rows );
}

sub totalresult {
    my $self = shift;
    return _calc_data( map {@$_} @{$self->{data}} );
}

1;
__END__
=head1 NAME

Data::TableAutoSum - Table that calculates the results of rows and cols automatic

=head1 SYNOPSIS

  use Data::TableAutoSum;
  
  my $table = Data::TableAutoSum->new(rows => 10, cols => 20);
  foreach my $row ($table->rows()) {
     foreach my $col ($table->cols()) {
        $table->data($row,$col) = rand();
        $table->data($row,$col) += $table->data($row-1,$col-1) 
            if $row >= 1 && $col >= 1;
     }
  }
  
  print "Row $_ has result: ",$table->rowresult($_) for $table->rows();
  print "Col $_ has result: ",$table->colresult($_) for $table->cols();
  print "Table has the total result: ",$table->totalresult();

  print "Let's have a look to the whole table:\n", $table->as_string;

=head1 ABSTRACT

Table object with automatic calculation of the row/column sums.

=head1 DESCRIPTION

This module represents a table with automatic calculation of the row/column sums.

=head2 FUNCTIONS

=over

=item new(rows => $nr_of_rows, cols => $nr_of_cols)

Creates a new, zero filled table.
The nr of rows and of cols must be greater than 0.

The rows and columns created are 0 .. $nr_of_rows-1 and
0 .. $nr_of_cols-1

=item data($row,$col,$new_value)

Get/set of data elements in the table.
$new_value is optional
Note, that the return value is an lvalue,
so you can e.g. set a new value
via $table->data($row,$col) = 4;
or modify all values with

  foreach my $row ($table->rows) {
    foreach my $col ($table->cols) {
      $table->data($row,$col) *= 1.05;
    }
  }

=item rows(), cols()

These functions are returning all rows/columns in a list.

It's not possible to set rows/columns with them.

=item rowresult($row), colresult($col)

Returns the sum for the specified row/col.

I named the methods *result instead of *sum,
as I plan to implement a possibility change the operation,
e.g. to max or multiplication.

You can't change the results directly.
Change the table data for that.

=item totalresult()

Returns the sum over all data elements.
totalresult is equal to the sum of all rowresults or the sum of all colresults
(of course, there could be some rounding errors).

You can't change the result directly.
Change the table data for that.

=item as_string()

Returns a string representation of the table.
A typical example could be:

        0     1    2   Sum
  0     2     9    4    15
  1     7     5    3    15
  2     6     1    8    15
  Sum  15    15   15    45

The string is a multiline string,
the elements of the table are seperated with a tab.

=back

=head2 EXPORT

None by default.
   
=head1 TODO

=over

=item Named Rows/Columns

Something like this snippet:

  my $table = Data::TableAutoSum->new(rows => ['New York', 'Chicago', 'L.A.'],
                                      cols => ['male', 'female', 'alien']);
                                      
  $table->data('New York','male') = 1_000_000;
  $table->data('L.A.', 'alien')   =   500_000;
  
  print "Aliens in U.S.A.:", $table->colresult('alien');
  print "Inhabitants of Chicagp:", $table->rowresult('Chicago');

=item options for as_string

The seperator, 
the end of line char,
and the "Sum"-string could be changed.

=item store/read

Some methods to store and read a table to/from a file.

=item operation

Possibility to change the internal used operation,
at the moment, only '+' is used.
I'd like to give the possibility to use any other distributive, associative 
operation.

=item change

A possibility to make something with all data elements,
like

  $table->change(sub {$_ *= 2});
  
=item merge

A static merging method,
that combines two table sets, like

  my $population = Data::TableAutoSum::merge(sub {$a + $b},
                                             $female_population,
                                             $male_population);
=item overloaded operators

Some operators should be overloaded.
I'd like to write something like

  my $population_perc = $population / $population->totalresult;
  my $euro_prices     = $dm_prices / 1.95883;
  
  my $population = $female_population + $male_population;
  my $murders_per_inhabitant = $murders / $inhabitants;
  
=item clear/fill

A clear method, that resets all values to 0
and a fill method to fill all elements with a specific value.

=item subtables

Something like

  my $east_alien_population = $population->subtable(rows => ['Chicago', 'New York'],
                                                    cols => 'alien');

Quite an insert_subtable method seems sensful, too.

=back     

=head1 REQUIREMENTS

   Params::Validate
   Regexp::Common
   Set::Scalar
   List::Util 
       
   Math::Random            # for the tests
   Set::CrossProduct  
   Data::Dumper       

   Test::More             
   Test::Exception    
   Test::Builder

=head1 SEE ALSO

L<Data::Xtab>,
L<Data::Pivot>,
L<Table::Pivoter>

=head1 AUTHOR

Janek Schleicher, E<lt>bigj@kamelfreund.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Janek Schleicher

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
