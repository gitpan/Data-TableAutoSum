package Data::TableAutoSum;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# I export nothing, so there aren't any @EXPORT* declarations

our $VERSION = '0.04';

use Params::Validate qw/:all/;
use Regexp::Common;
use Set::Scalar;
use List::Util qw/reduce/;
use Tie::File;

sub implies($$) {
    my ($x, $y) = @_;
    return !$x || ($x && $y);
}

sub is_uniq(@) {
    my %items;
    foreach (@_) {
        return 0 if $items{$_}++;
    }
    return 1;
}

use constant ROW_COL_TYPE => {
    type      => SCALAR | ARRAYREF,
    callbacks =>  {
        # scalar value
        'integer'          => sub { implies !ref($_[0]) => $_[0] =~ $RE{num}{int} },
        'greater than 0'   => sub { implies !ref($_[0]) => ($_[0] > 0) },
        
        # array ref
        'uniq identifiers' => sub { no strict 'refs';
                                    implies ref($_[0])  => is_uniq @{$_[0]} },
        'some identifiers' => sub { no strict 'refs';
                                    implies ref($_[0])  => @{$_[0]} }
    }
};

sub new {
    my $proto = shift;
    my %arg = validate( @_ => {rows => ROW_COL_TYPE, cols => ROW_COL_TYPE} );
    my $class = ref($proto) || $proto;
    my @rows = ref($arg{rows}) ? @{$arg{rows}} : (0 .. $arg{rows}-1);
    my @cols = ref($arg{cols}) ? @{$arg{cols}} : (0 .. $arg{cols}-1);
    my %data;
    foreach my $row (@rows) {
        foreach my $col (@cols) {
            $data{$row}->{$col} = 0;
        }
    }
    my $self = {
        rows   => \@rows,
        rowset => Set::Scalar->new(@rows),
        cols   => \@cols,
        colset => Set::Scalar->new(@cols),
        data   => \%data
    };
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
    $self->{data}->{$row}->{$col} = $value if defined $value;
    $self->{data}->{$row}->{$col};
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

sub store {
    my ($self, $filename) = @_;
    open FILE, ">$filename" or die "Can't open $filename to store the table: $!";
    print FILE $self->as_string;
    close FILE;
    return $self;
}

sub read {
    my ($class, $filename) = @_;
    tie my @data, 'Tie::File', $filename
        or die "Can't open $filename to read the table: $!";
    
    my @header       = split /\t/, $data[0];
    my @col = @header[1 .. $#header-1];
    my @row = map {/^([^\t]*)\t/} map {$data[$_]} (1 .. $#data-1); 
    my $table        = $class->new(rows => \@row, cols => \@col);
    
    foreach my $i (0 .. $#row) {
        my @line = split /\t/, $data[$i+1];
        foreach my $j (0 .. $#col) {
            $table->data($row[$i],$col[$j]) = $line[$j+1];
        }
    }
        
    untie @data;
    return $table;
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
    return _calc_data( map {values %$_} values %{$self->{data}} );
}

1;
__END__
=head1 NAME

Data::TableAutoSum - Table that calculates the results of rows and cols automatic

=head1 SYNOPSIS

  use Data::TableAutoSum;
  
  my $table = Data::TableAutoSum->new(rows => 10, cols => 20); 
  # or
  my $table = Data::TableAutoSum->new(rows => ['New York', 'L.A.', 'Chicago'],
                                      cols => ['Women', 'Men', 'Alien']);
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

  $table->store('random.dat');
  my $old_random_data = Data::TableAutoSum->read('random.dat');

=head1 ABSTRACT

Table object with automatic calculation of the row/column sums.

=head1 DESCRIPTION

This module represents a table with automatic calculation of the row/column sums.

=head2 FUNCTIONS

=over

=item new(rows => $nr_of_rows || \@rows, cols => $nr_of_cols || \@cols)

Creates a new, zero filled table.
You can define the rows or cols with a ref to an array of the names
of the rows/cols.
If so, the names have to be unique.
If you only give a number,
the rows/cols are named C<(0 .. $nr-1)>.

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
They are returned in the order as given with the new constructor.

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

=item store($filename)

Stores the table in a readable format (the same as used by as_string)
into the specified file.

C<store> returns the table object itselfs,
so you can use it in the fashion way:

  print "Stored the table\n", $table->store($filename)->as_string;

=item Data::TableAutoSum->read($filename)

Constructs a table found in the filename.
It expects a table of the format written by store,
what is the same like written with as_string.

I didn't test what happens,
using wrong formated files or similar.
You're supposed to don't do that.

=back

=head2 EXPORT

None by default.

=head1 BUGS

The store/read methods are slow.
As I wrote the module for convienience,
it's not so important for me,
but I'll change it a day.

It's not tested
what happens when you try to read a misformatted table.
Don't do that.

If you work with floating point types,
don't expect that
$table->store('filename')->read('filename')
reproduces exactly the same table,
as there could be some rounding errors.

I hope there aren't any more bugs.
   
=head1 TODO

=over

=item options for as_string, store, read

The seperator, 
the end of line char,
and the "Sum"-string should be changeable.

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

=item increase speed of store/read

=back     

=head1 REQUIREMENTS

   Params::Validate
   Regexp::Common
   Set::Scalar
   List::Util 
   Tie::File
       
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
