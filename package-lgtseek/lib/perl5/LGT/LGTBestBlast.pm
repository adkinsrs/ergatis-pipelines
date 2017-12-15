
=head1 NAME

LGTBestBlast - Run blast and filter for best hits.

=head1 SYNOPSIS

Need to put something useful here

=head1 DESCRIPTION

A module to run BLAST or take existing blast -m8 output and filter it for
best hit. Also appends Lineage information onto each hit.

=head1 AUTHOR - David R. Riley

e-mail: driley@som.umaryland.edu

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package LGT::LGTBestBlast;
use strict;
use warnings;
use File::Basename;
use Carp;
$Carp::MaxArgLen = 0;
$|               = 1;

# Globals
my $filter_hits = [];
my $lineage     = {};
my $gi2tax;
my $outfile;
my $FILTER_MIN_OVERLAP = 50;
my $BLAST_BIN          = '/usr/local/bin/blastall';
my $BLAST_CMD_ARGS     = ' -p blastn -e 1 -m8';
my $filter_lineage;
my $min_overlap;

=head2 &filterBlast

 Title   : filterBlast
 Usage   : my $bestBlast = LGTBestBlast::filterBlast({fasta => $fasta,...})
 Function: Returns the path to filtered blast reports
 Returns :  Hash ref. of filtered blast hits.

            list_file     => list of the files below
            outfile => best lineage hits,

 Args    : A hash containing potentially several config options:

           fasta - Path to a fasta file to search
           blast - Path to an existing blast output
           db - One or more fasta files to use a host references
           output_dir - One or more fasta files to use as donor references
           blast_bin - path to blast (Can also contain some arguments)
           lineage - Lineage to donor or host reference
           gitaxon - A GiTaxon object

=cut

sub filterBlast {
    my ( $class, $args ) = @_;

# Default filter min overlap is 50 (minimum length to filter out overlapping reads
    $min_overlap =
        $args->{filter_min_overlap}
      ? $args->{filter_min_overlap}
      : $FILTER_MIN_OVERLAP;
    $filter_lineage = $args->{filter_lineage};

    # Figure out what inputs we have
    my $input;
    if ( $args->{fasta} ) {
        $input = $args->{fasta};
    } elsif ( $args->{blast} ) {
        $input = $args->{blast};
    }

    if ( !$input ) {
        confess "Need to provide a fasta or a blast file for blast\n";
    }

    # Initialize gi2taxon db.
    $gi2tax = $args->{gitaxon};
    if ( !$gi2tax ) { confess "Need to provide a gitaxon object\n"; }

    # Get the basename of the input file.
    my ( $name, $directories, $suffix ) = fileparse( $input, qr/\.[^.]*/ );

    &_init_lineage( $args, $name );

    $args->{blast_bin} = $BLAST_BIN if !defined( $args->{blast_bin} );
    my $fh;

    # Use blast results if already provided, otherwise run blast to get results
    if ( $args->{blast} ) {
        print STDERR "Opening blast input.\n";
        open( $fh, "<$input" ) or confess "Unable to open $input\n";
    } elsif ( !$args->{blast} ) {
        open( $fh, "-|",
            "$args->{blast_bin} $BLAST_CMD_ARGS -d $args->{db} -i $input" )
          or confess
          "Unable to run: $args->{blast_bin} on: $input with db: $args->{db}\n";
    }
    &_process_file($fh);
    my $list = &_create_list_of_outputs($args);

    close $lineage->{handle};

    return {
        list_file => $list,
        outfile   => $outfile,
    };
}

# Initialize the lineage hashes for the donor, the host, and overall
sub _init_lineage {
    my $args = shift;
    my $name = shift;
    if ( $args->{lineage} ) {
        my $lineage_name = $args->{lineage};
        $outfile = $args->{output};
        if ( !$args->{output} && $args->{output_dir} ) {
            $outfile = $args->{output_dir} . "/$name\_$lineage_name.out";
        }
        open my $out_fh, ">$outfile"
          or confess "Unable to open lineage1 output $outfile\n";

        $lineage = {
            'lineage' => $args->{lineage},
            'best_e'    => 100,      # Dummy value so next will always be better
            'best_bit'  => 0,
            'id'        => '',
            'handle'    => $out_fh,
            'best_rows' => [],
            'name'      => 'lineage'
        };
    }
}

# Process the BLAST m8 output.
sub _process_file {
    my $fh = shift;
    use Data::Dumper;
    while ( my $line = <$fh> ) {
        chomp $line;
        my @fields = split( /\t/, $line );
        my $tax;
        my $found_tax = 0;

        # If we already have lineage info in here we'll not append it again
        if ( $fields[14] ) {
            $found_tax = 1;
            $tax       = {
                'taxon_id' => $fields[12],
                'lineage'  => $fields[14],
                'name'     => $fields[13]
            };
        } else {
            $tax = $gi2tax->getTaxon( $fields[1] );
        }

        # If taxon info was not already in m8 file, add it
        if ( !$found_tax ) {
            push( @fields,
                ( $tax->{taxon_id}, $tax->{name}, $tax->{lineage} ) );
        }

        # Die if we are missing key info
        carp
          "Unable to find name or lineage for taxon_id $tax->{'taxon_id'} in trace $fields[1]\n"
          unless $tax->{name};
        carp "Unable to find taxon info for $fields[1]\n"
          unless $tax->{taxon_id};

        my $fields_w_trace = &_add_trace_info( \@fields );

        my $done = 0;
        $done = &_process_line( $fields_w_trace, $tax, $lineage );

        $filter_hits = [] if $done;
    }
    close $fh;

    # here we'll take care of the last trace in the file.
    &_print_hits($lineage);
}

sub _process_line {
    my ( $fields, $tax, $lineage ) = @_;

    my $finished_id = 0;

    # If our best lineage ID has been identified as the current query ID...
    if ( $lineage->{id} eq $fields->[0] ) {

        # SAdkins - 11/20/17 - Changed from using best e-val to best bit score instead
        # Determining how to handle equal or better hits
        if ( $fields->[11] == $lineage->{best_bit} ) {

            # If our hit is equally as good as our best, then allow for more than one best hit
            push( @{ $lineage->{best_rows} }, $fields );
        } elsif ( $fields->[11] > $lineage->{best_bit} ) {
            $lineage->{best_bit}  = $fields->[11];
            $lineage->{best_rows} = [$fields];
        }
    } else {    # If we are ready to move on to the next Query ID
                # We have finished a hit
        &_print_hits($lineage);
        $finished_id = 1;

        # Store new hit as the first 'best hit'.
        $lineage->{id}        = $fields->[0];
        $lineage->{best_e}    = $fields->[10];
        $lineage->{best_bit}  = $fields->[11];
        $lineage->{best_rows} = [$fields];

        if ( &_filter_hit( $tax->{name} ) ) {
            push( @$filter_hits, $fields );
        }
        return $finished_id;
    }
}

# Print out the best hit for this particular query ID.
sub _print_hits {
    my $lineage = shift;
    if ( $lineage->{id} ) {

        # We have finished a hit
        if ( scalar @{ $lineage->{best_rows} } ) {
            if ( !&_filter_best_hits( $lineage->{best_rows} ) ) {
                map {
                    print { $lineage->{handle} } join( "\t", @$_ );
                    print { $lineage->{handle} } "\n";
                } @{ $lineage->{best_rows} };
            } else {
                print STDERR "Filtered $lineage->{name}\n";
            }
        }
    }
}

# Append trace information to the passed-in m8 hit.
# Adds 'template_id', which is assuned to the query name
# Adds 'trace_end', which is either forward or reverse.
sub _add_trace_info {
    my $list = shift;

    my $id = $list->[0];

    # Ghetto way of checking for directionality.
    my $dir = 'F';
    if ( $id =~ /(.*)[\_\/](\d)/ ) {

        # Determine forward and reverse by which mate pair it is
        if ( $2 == 1 ) {
            push( @$list, ( $1, 'F' ) );
        } elsif ( $2 == 2 ) {
            push( @$list, ( $1, 'R' ) );
        } else {
            print STDERR
              "Couldn't figure out the clone name from $list->[0] assuming F\n";
            push( @$list, ( $1, 'F' ) );
        }
    }
    return $list;
}

# Ensure query and subject have enough overlap to be a great hit
sub _filter_best_hits {
    my $hits   = shift;
    my $filter = 0;
    foreach my $fhit (@$filter_hits) {
        foreach my $hit (@$hits) {
            my $overlap = &_get_overlap_length( [ $fhit->[6], $fhit->[7] ],
                [ $hit->[6], $hit->[7] ] );
            if ( $overlap >= $min_overlap ) {
                print STDERR
                  "Here to filter out $hit->[0] $fhit->[14] with $overlap\n";
                $filter = 1;
                last;
            }
        }
        last if $filter;
    }
    return $filter;

}

# If argument was provided to filter a specific lineage, then do it
sub _filter_hit {
    my $lineage = shift;

    my $retval = 0;
    if ( $filter_lineage && $lineage =~ /$filter_lineage/i ) {
        print STDERR "Filtering out because of $lineage\n";
        $retval = 1;
    }
    return $retval;
}

sub _get_overlap_length {
    my ( $q, $s ) = @_;

    my $qlen = $q->[1] - $q->[0];
    my $slen = $s->[1] - $s->[0];
    my $min  = min( $q->[1], $q->[0], $s->[1], $s->[0] );
    my $max  = max( $q->[1], $q->[0], $s->[1], $s->[0] );

    my $len = ( $qlen + $slen ) - ( $max - $min );

    return $len;
}

sub _create_list_of_outputs {
    my $config = shift;
    my $out_dir;
    my ( $name, $directories, $suffix );
    if ( $config->{output_dir} ) {
        $out_dir = $config->{output_dir};
    }

    if ( $config->{fasta} ) {
        ( $name, $directories, $suffix ) =
          fileparse( $config->{fasta}, qr/\.[^.]*/ );
        $out_dir = $directories if !defined $out_dir;
    } elsif ( $config->{blast} ) {
        ( $name, $directories, $suffix ) =
          fileparse( $config->{blast}, qr/\.[^.]*/ );
        $out_dir = $directories if !defined $out_dir;
    } else {
        confess "Must pass &BestBlast2 an output_dir. $!\n";
    }
    open OUT, ">$out_dir/$name\_filtered_blast.list"
      or confess "Unable to open $out_dir/$name\_filtered_blast.list\n";
    print OUT "$outfile\n";
    close OUT;
    return "$out_dir/$name\_filtered_blast.list";
}

1;
