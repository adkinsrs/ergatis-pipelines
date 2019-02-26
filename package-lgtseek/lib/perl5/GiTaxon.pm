
=head1 NAME

GiTaxon

=head1 DESCRIPTION

Utility to look up taxon information in a mongo database.

=head1 AUTHOR
Shaun Adkins
sadkins@som.umaryland.edu

=cut

package GiTaxon;
use strict;
use warnings;
use MongoDB; #v2.0.1
use Bio::DB::Taxonomy;
use Bio::DB::EUtilities;
use File::Find;
use Try::Tiny;

my $NODES = '/local/db/repository/ncbi/blast/20120414_001321/taxonomy/taxdump/nodes.dmp';
my $NAMES =  '/local/db/repository/ncbi/blast/20120414_001321/taxonomy/taxdump/names.dmp';
my $GI2TAX = '/local/db/repository/ncbi/blast/20120414_001321/taxonomy/gi_taxid_nucl.dmp';
my $CHUNK_SIZE = 10000;
my $HOST = 'him.igs.umaryland.edu:10001';
my $DB = 'gi2taxon';
my $COLL = 'gi2taxonnuc';
my $TMP = '/tmp';

sub new {
    my ( $class, $args ) = @_;

    my $self = {};

    # If we choose to not provide any taxonomy flatfiles, enable this property
    # This will cause all taxon entries to be added from the Entrez database
    $self->{'no_flatfiles'} =
        $args->{'no_flatfiles'}
        ? $args->{'no_flatfiles'}
        : 0;

    # Nodes/Names/Gi2Tax will only matter if no_flatfiles = 0
    $self->{'nodes'} =
        $args->{'nodes'}
        ? $args->{'nodes'}
	    : $NODES;
    $self->{'names'} =
        $args->{'names'}
        ? $args->{'names'}
	    : $NAMES;

    $self->{'gi2tax'} =
        defined $args->{'gi2tax'}
        ? $args->{'gi2tax'}
        : '';

    $self->{'load'} =
        defined $args->{'load'}
        ? $args->{'load'}
        : 0;

    $self->{'chunk_size'} =
      $args->{'chunk_size'} ? $args->{'chunk_size'} : $CHUNK_SIZE;
	$self->{'host'} = 'mongodb://';
    $self->{'host'} .=
      $args->{'host'} ? $args->{'host'} : $HOST;
	$self->{'gi_db'} = $args->{'gi_db'} ? $args->{'gi_db'} : $DB;
    $self->{'gi_coll'} =
      $args->{'gi_coll'} ? $args->{'gi_coll'} : $COLL;
    $self->{'taxonomy_dir'} = $args->{'taxonomy_dir'} ? $args->{'taxonomy_dir'} : $TMP;

    $self->{'cache'} = {};

    $self->{'type'} = $args->{'type'} ? $args->{'type'} : 'nuccore';
    my $gi_tax_file = 'gi_taxid_nucl.dmp';
    if ( $self->{'type'} eq 'protein' ) {
        $gi_tax_file = 'gi_taxid_prot.dmp';
    }

# This option can be used if the user want's to override all the nodes/names params at once
    if ( $args->{'taxon_dir'} ) {
        print STDERR "Here with a taxon directory $args->{'taxon_dir'}\n";

        # Find the nodes, names and nucleotide mapping file
        find(
            sub {
                if ( $File::Find::name =~ /nodes.dmp/ ) {
                    $self->{'nodes'} = $File::Find::name;
                }
                elsif ( $File::Find::name =~ /names.dmp/ ) {
                    $self->{'names'} = $File::Find::name;
                }
                elsif ( $File::Find::name =~ /$gi_tax_file/ ) {
                    $self->{'gi2tax'} = $File::Find::name;
                }
            },
            $args->{'taxon_dir'}
        );
        if ( !$args->{'gi_coll'} ) {
            if ( $args->{'taxon_dir'} =~ /(\d+\_\d+)/ ) {
                my $date = $1;
                if ( $self->{'type'} eq 'nucleotide' ) {
                    $self->{'gi_coll'} = "gi2taxonnuc_$date";
                }
                else {
                    $self->{'gi_coll'} = "gi2taxonprot_$date";
                }
            }
        }
    }

    if (! $self->{'no_flatfiles'}) {
        $self->{'db'} = Bio::DB::Taxonomy->new(
            -source    => 'flatfile',
            -nodesfile => $self->{'nodes'},
            -namesfile => $self->{'names'},
            -directory => $self->{'taxonomy_dir'}
        );
    }

    if ( $args->{verbose} ) {
        if ($self->{'no_flatfiles'}) {
            print STDERR "======== &Gi2Taxon - Not using NCBI taxonomy flatfiles\n";
        } else {
            print STDERR "======== &Gi2Taxon - Using $self->{nodes}\n";
            print STDERR "======== &Gi2Taxon - Using $self->{names}\n";
            print STDERR "======== &Gi2Taxon - Using $self->{gi2tax}\n";
        }
        print STDERR "======== &Gi2Taxon - Using $self->{'taxonomy_dir'}\n";
        print STDERR "======== &Gi2Taxon - Using $self->{'gi_coll'}\n";
        print STDERR "======== &Gi2Taxon - Using $self->{'host'}\n";
    }
    bless $self;

    $self->{'mongo'} =
      $self->get_mongodb_connection( $self->{'gi_db'}, $self->{'host'} );
    $self->{'gi2taxon'} = $self->getgi2taxon( $self->{'mongo'}, $self->{'gi2tax'}, $self->{'load'});

    return $self;
}

sub getTaxon {
    my ( $self, $acc ) = @_;
    $acc =~ s/^\s+//;
    $acc =~ s/\s/\t/;
    my $gi = $acc;
    if ( $acc =~ /\|/ ) {
        my @fields = split( /\|/, $acc );
        $gi = $fields[1];
    }
    my $taxonid = '';
    my $retval  = {};
    # First check the cache
    if ( $self->{cache}->{$gi} ) {
        return $self->{cache}->{$gi};
    } else {
        my $taxon_lookup =
          $self->{'gi2taxon'}->find_one( { 'gi' => "$gi" }, { 'taxon' => 1 } );
        if ($taxon_lookup) {
            $taxonid = $taxon_lookup->{'taxon'};
        } else {
			#print STDERR "*** GiTaxon-getTaxon: Unable to find taxon for $gi, Checking NCBI\n";
            # Sometimes $gi is null
            try {
                my $factory = Bio::DB::EUtilities->new(
                    -eutil => 'esummary',
                    -email => 'example@foo.bar',
                    -db    => $self->{'type'},
                    -id    => [$gi]
                );
                sleep 3;

                # Catch potential object error
                if ($factory->get_count == 0) {
                    warn $gi . " - No hits returned\n";
                }

                while ( my $ds = $factory->next_DocSum ) {
                    my @res = $ds->get_contents_by_name('TaxId');
                    if (@res) {
                        $taxonid = $res[0];
                    }
                    if ( ! defined $taxonid ) {
                        print STDERR "Unable to find taxonid at NCBI\n";
                    }
                    else {
                        my $res = $self->{'gi2taxon'}->update_one(
                            { 'gi'     => "$gi" },
                            { '$set' => { 'gi'     => "$gi", 'taxon' => $taxonid } },
                            { 'upsert' => 1, 'safe' => 1 }
                        );
                        #print STDERR "*** GiTaxon-getTaxon: Added $gi\t$taxonid to the db\n";
                    }
                }
            } catch {
                warn "Caught error for ID $gi : $_";
                # Since we can't get a taxon ID, just return empty-handed
                return $retval;
            }
        }

        ## NEW VVV 01.08.15 KBS v1.07
        ## I added this so that if the gi isn't in our DB we pull the data from NCBI
        if ( ! $self->{'no_flatfiles'} &&
            ( my $taxon = $self->{'db'}->get_taxon( -taxonid => $taxonid ) ) ) {
            if ( $taxon->isa('Bio::Taxon') ) {
                my $name    = $taxon->scientific_name;
                my $c       = $taxon;
                my @lineage = ($name);
                while ( my $parent = $self->{'db'}->ancestor($c) ) {
                    unshift @lineage, $parent->scientific_name;
                    $c = $parent;
                }
                $retval = {
                    'gi'       => $gi,
                    'acc'      => $acc,
                    'taxon_id' => $taxonid,
                    'name'     => $name,
                    'lineage'  => join( ";", @lineage )
                };
            }
        }
        else {
            # Sometimes $taxonid is null
            try {
                my $db = Bio::DB::Taxonomy->new( -source => 'entrez' );
                my $taxon = $db->get_taxon( -taxonid => $taxonid );
                sleep 3;
                if (defined($taxon) && $taxon->isa('Bio::Taxon') ) {
                    my $name    = $taxon->scientific_name;
                    my $c       = $taxon;
                    my @lineage = ($name);
                    while ( my $parent = $db->ancestor($c) ) {
                        unshift @lineage, $parent->scientific_name;
                        $c = $parent;
                    }
                    $retval = {
                        'gi'       => $gi,
                        'acc'      => $acc,
                        'taxon_id' => $taxonid,
                        'name'     => $name,
                        'lineage'  => join( ";", @lineage )
                    };
                }
                else {
                    print STDERR "**GiTaxon unable to find taxon for taxon_id: $taxonid & gi:$gi\n";
                }
            } catch {
                warn "Caught error for taxon ID $taxonid : $_";
            }
        }

        ## NEW ^^^ 01.08.15 KBS v1.07
        $self->{cache}->{$gi} = $retval;
    }
    return $retval;
}

# Insert data from the data dump file into the MongoDB collection if the collection does not exist
sub getgi2taxon {
    my ( $self, $mongo, $data_file, $load ) = @_;
    my $coll = $mongo->get_collection( $self->{'gi_coll'} );
	# If collection not found in database, update the db using the datafile
    if ($data_file) {
        print "Loading data to Mongo\n" if $load;
	    if ( !$coll->find_one() || $load ) {
            print STDERR
"Found nothing in database $self->{gi_db} collection $self->{gi_coll} on $self->{host}\n";
            print "Getting the line count of the data file...\n";
            my $lc = `wc -l $data_file`;
            chomp $lc;
            $lc =~ s/\s.*//;
            print "Got the line count - Lines: $lc\n";
            open IN, "<$data_file" or die "Unable to open $data_file\n";
            my $num_in_chunk = 0;
            my $total        = 0;
            my @chunk;

		      # In the data file, add new data to MongoDB database in chunks
            while (<IN>) {
                chomp;
                $num_in_chunk++;
                my ( $gi, $taxon ) = split( /\t/, $_ );
                # Determine if GI is in collection and update if taxon IDs do not match.
                my $taxon_lookup = $coll->find_one( { 'gi' => "$gi" }, { 'taxon' => 1});
                if ($taxon_lookup) {
                    if ($taxon_lookup->{'taxon'} ne $taxon) {
                        $coll->update_one(
                            { 'gi'     => "$gi" },
                            { '$set' => { 'gi'     => "$gi", 'taxon' => $taxon } },
                            { 'upsert' => 1, 'safe' => 1 }
                        );
                    }
                    next;
                }
                push( @chunk, { 'gi' => $gi, 'taxon' => $taxon } );
                if ( $num_in_chunk == $self->{'chunk_size'} ) {
                    $total += $num_in_chunk;
                    print join(
                        "",
                        (
                            "\r", ( sprintf( '%.2f', ( ( $total / $lc ) * 100 ) ) ),
                            "% complete"
                        )
                    );
                    $self->insert_chunk( $coll, \@chunk );
                    @chunk        = ();
                    $num_in_chunk = 0;
                }
            }
            $self->insert_chunk( $coll, \@chunk );

            close IN;
            $coll->ensure_index( { 'gi' => 1 }, { 'safe' => 1 } );
		}
	}
    return $coll;
}

sub insert_chunk {
    my $self  = shift;
    my $coll  = shift;
    my $chunk = shift;

    $coll->insert_many( $chunk, { 'safe' => 1 } );      # Uses newer MongoDB
}

sub get_mongodb_connection {
    my ( $self, $dbname, $host ) = @_;

    # First we'll establish our connection to mongodb
    my $client = MongoDB::MongoClient->new({
        'host'=>$host, 
        'socket_timeout_ms'=>120000
    });
    return $client->get_database($dbname);
}

sub mongo_disconnect {
    my ($self) = @_;
    my $mongo = $self->{'mongo'};
    $mongo->disconnect();
}
1;
