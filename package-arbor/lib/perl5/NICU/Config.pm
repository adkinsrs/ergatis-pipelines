package NICU::Config;

our @EXPORT = qw(read_config write_config);

# Config.pm - Subroutines to convert config file parameters to and from a hash data structure

# read_config - Read a ergatis-formatted config file and create a hash structure out of the parameters
sub read_config {
    my $phOptions       = shift;
    my $phConfig        = shift;
    
    ## make sure config file and config hash are provided
    if ((!(defined $phOptions->{'config'})) || 
        (!(defined $phConfig))) {
        die "Error! In subroutine read_config: Incomplete parameter list !!!\n";
        }
        
        my ($sConfigFile);
        my ($sComponent, $sParam, $sValue, $sDesc);
        my ($fpCFG);
        
        if (defined $phOptions->{'config'}) {
                $sConfigFile = $phOptions->{'config'};
        }
        open($fpCFG, "<$sConfigFile") or die "Error! Cannot open $sConfigFile for reading: $!";
        
        $sComponent = $sParam = $sValue = $sDesc = "";
        while (<$fpCFG>) {
                $_ =~ s/\s+$//;
                next if ($_ =~ /^#/);
                next if ($_ =~ /^$/);
                
                if ($_ =~ m/^\[(\S+)\]$/) {
                        $sComponent = $1;
                        next;
                }
                elsif ($_ =~ m/^;;\s*(.*)/) {
                        $sDesc .= "$1.";
                        next;
                }
                elsif ($_ =~ m/\$;(\S+)\$;\s*=\s*(.*)/) {
                        $sParam = $1;
                        $sValue = $2;
                        
                        if ((defined $sValue) && ($sValue !~ m/^\s*$/)) {
                                $phConfig->{$sComponent}{$sParam} = ["$sValue", "$sDesc"];
                        }
                        
                        $sParam = $sValue = $sDesc = "";
                        next;
                }
        }
        
        close($fpCFG);
            
    return;
}

# write_config - Write an ergatis-formatted config file using hash keys
sub write_config {
    my $phCmdLineOption = shift;
    my $phConfig            = shift;
    my $sConfigFile             = shift;
    
    ## make sure config file and config hash are provided
    if ((!(defined $phCmdLineOption)) ||  
        (!(defined $phConfig)) || 
        (!(defined $sConfigFile))) {
        die "Error! In subroutine read_config: Incomplete parameter list !!!\n";
        }
        
        my ($sComponent, $sParam, $sValue, $sDesc);
        my ($fpCFG);
        
        open($fpCFG, ">$sConfigFile") or die "Error! Cannot open $sConfigFile for writing: $!";
        
        foreach $sComponent (sort {$a cmp $b} keys %{$phConfig}) {
                print $fpCFG "[$sComponent]\n";
                foreach $sParam (sort {$a cmp $b} keys %{$phConfig->{$sComponent}}) {
                        $sDesc = ((defined $phConfig->{$sComponent}{$sParam}[1]) ? $phConfig->{$sComponent}{$sParam}[1] : "");
                        print $fpCFG ";;$sDesc\n" if ((defined $sDesc) && ($sDesc !~ m/^$/));
                        
                        $sValue = ((defined $phConfig->{$sComponent}{$sParam}[0]) ? $phConfig->{$sComponent}{$sParam}[0] : undef);
                        print $fpCFG "\$;$sParam\$\; = ";
                        print $fpCFG "$sValue" if (defined $sValue);
                        print $fpCFG "\n";
                }
                print $fpCFG "\n";
        }
        
        close($fpCFG);
    
    return;
}

1;
