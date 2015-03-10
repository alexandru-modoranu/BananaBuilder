use strict;
use warnings;
use File::Find::Rule;
use File::Copy;
use File::Spec;
use File::Path;
use Cwd;
use Env qw(TS_LOCAL PATH);
use Module::Load;

my $Version = 0.01;

my $pdCwd = getcwd();
chdir "..";
my $cwd = getcwd();

(@ARGV == 2) or die "\nAccepted arguments are clean, build, rebuild, tree\n";

my %pdHash;
my $pdFile;
my $builderGoal;
my @steps;
my $entirePd;
my $toolchainPath;
my $projectName;

if ($ARGV[1] eq "clean" || $ARGV[1] eq "build" || $ARGV[1] eq "rebuild" || $ARGV[1] eq "tree")
{
    $pdFile = $ARGV[0];
    $builderGoal = $ARGV[1];
    parsePd();
}
else
{
    die "\nArgument not recognized! Accepted arguments are clean, build, rebuild.\n";
}

########################################################################
###                       Subfunctions area                          ###
########################################################################
sub parsePd
{
    # Read entire project description reference file into a variable
    {
        local(*INFILE, $/);
        open(INFILE, "<", "$pdCwd/$pdFile") or die "Cannot open $pdFile: $!";
        $entirePd = <INFILE>;
    }

    # Find all the build steps
    $entirePd =~ s/([\/\/]*)\[(step\w{3,}~{0,}.*)\]/$1$2/g;

    @steps = $entirePd =~ /([\/\/]*step\w{3,}~{0,}.*)/g;

    foreach my $stepValue (0..$#steps)
    {
        if ($steps[$stepValue] =~ /^[^\/\/]+/)
        {
            my $startString;
            my $endString;
            my $stepData;

            if ($stepValue < $#steps)
            {
                ($startString) = $steps[$stepValue] =~ /(step\w{3,}~{0,}.*)/;
                ($endString) = $steps[$stepValue + 1] =~ /([\/\/]*step\w{3,}~{0,}.*)/;
            }
            else
            {
                ($startString) = $steps[$stepValue] =~ /(step\w{3,}~{0,}.*)/;
                $endString = "";
            }

            ($stepData) = $entirePd =~ /$startString(.+)$endString/s;

            if ($steps[$stepValue] =~ /^(step\w+)~(.+)\s*/)
            {
                my $stepName = $1;
                my $stepFile = $2;

                $stepData =~ s/\s*\/{2,}.*\n/\n/g;
                $stepData =~ s/\n{2,}/\n/g;
                $stepData =~ s/^\n//g;
                $stepData =~ s/^\s+|\s+$//g;
                $pdHash{$stepName}{$stepFile} = $stepData;
            }
            elsif ($steps[$stepValue] =~ /^(step\w+).*/)
            {
                my $stepName = $1;
                my @stepSubRef;

                @stepSubRef = $stepData =~ /^(.+)=.*$/gm;

                foreach my$stepSubRefValue (0..$#stepSubRef)
                {
                    my $stepSubRefData;

                    if ($stepSubRefValue < $#stepSubRef)
                    {
                        ($stepSubRefData) = $stepData =~ /$stepSubRef[$stepSubRefValue]=(.*)$stepSubRef[$stepSubRefValue + 1]/s;
                    }
                    else
                    {
                        ($stepSubRefData) = $stepData =~ /$stepSubRef[$stepSubRefValue]=(.*)/s;
                    }

                    $stepSubRefData =~ s/\s*\/{2,}.*\n/\n/g;
                    $stepSubRefData =~ s/\n{2,}/\n/g;
                    $stepSubRefData =~ s/^\n//g;
                    $stepSubRefData =~ s/\s*[\\]+\s+/ /g;
                    $stepSubRefData =~ s/^\s+|\s+$//g;

                    $pdHash{$stepName}{$stepSubRef[$stepSubRefValue]} = $stepSubRefData;
                }
            }
        }
    }

    # Extract some data from step000
    if (exists $pdHash{'step000'})
    {
        if (exists $pdHash{'step000'}{'LOCAL'} and exists $pdHash{'step000'}{'PLATFORM'})
        {
            $pdHash{'step000'}{'PLATFORM'} =~ s/:{1,}/\//;
            $toolchainPath = "$pdHash{'step000'}{'LOCAL'}/$pdHash{'step000'}{'PLATFORM'}/bin";
        }
        else
        {
            die "ERROR: No toolchain defined!\n";
        }

        if (exists $pdHash{'step000'}{'PRJ_NAME'})
        {
            $projectName = "$pdHash{'step000'}{'PRJ_NAME'}";
        }
        else
        {
            die "ERROR: No toolchain defined!\n";
        }
    }
    else
    {
        die "ERROR: No project information defined!\n";
    }

    # Run the goal execution of every step in the PD file
    foreach my $item (sort keys %pdHash)
    {
        my %tmpHash;

        $tmpHash{'BUILDGOAL'} = $builderGoal;
        $tmpHash{'PRJ_PATH'} = $cwd;
        $tmpHash{'PD_PATH'} = $pdCwd . "/$pdFile";
        $tmpHash{'VERSION'} = $Version;
        $tmpHash{'TOOLCHAIN_PATH'} = $toolchainPath;
        $tmpHash{'NAME'} = $projectName;

        foreach my $iteminitem (keys %{$pdHash{$item}})
        {
            $tmpHash{$iteminitem} = $pdHash{$item}{$iteminitem};
        }

        load $item;
        $item->executeGoal(\%tmpHash);

        last if ($builderGoal eq 'clean');
    }

    # Create build reports
    createSummaryReport();

}

sub createSummaryReport
{
    my $tmpFolder = "$cwd/tmp";
    my @infoFiles = my @files = File::Find::Rule->file
                                                ->name('*.ok') # search by file extensions
                                                ->in($tmpFolder);
    my @warningFiles = my @files = File::Find::Rule->file
                                                   ->name('*.warn') # search by file extensions
                                                   ->in($tmpFolder);
    my @errorFiles = my @files = File::Find::Rule->file
                                                 ->name('*.error') # search by file extensions
                                                 ->in($tmpFolder);

    if (exists $pdHash{'step000'}{'VERBOSITY'} and $pdHash{'step000'}{'VERBOSITY'} < 10 )
    {
        print "______________________ End of Report _______________________\n";
        my $noErrorFiles = $#errorFiles + 1;
        my $noWarningFiles = $#warningFiles + 1;
        my $noInfoFiles = $#infoFiles + 1;
        print "***Log files status : errors in $noErrorFiles file(s), warnings in $noWarningFiles file(s), informations in $noInfoFiles file(s)\n";
        print "***Log files are available in the [root/tmp] directory\n";
    }
    else
    {
        print "______________________ Summary Report ______________________\n";
        foreach my $errorFile (sort @errorFiles)
        {
            my $fileData;
            my ($errorFilename) = $errorFile =~ /.+[\/|\\](.+)/g;

            print "__________ $errorFilename ___________\n";
            {
                local(*INFILE, $/);
                open(INFILE, "<", "$tmpFolder/$errorFilename") or die "Cannot open $errorFilename: $!";
                print <INFILE>;
            }
        }

        foreach my $warningFile (sort @warningFiles)
        {
            my $fileData;

            my ($warningFilename) = $warningFile =~ /.+[\/|\\](.+)/g;

            print "__________ $warningFilename ___________\n";
            {
                local(*INFILE, $/);
                open(INFILE, "<", "$tmpFolder/$warningFilename") or die "Cannot open $warningFilename: $!";
                print <INFILE>;
            }
        }

        print "______________________ End of Report _______________________\n";
        my $noErrorFiles = $#errorFiles + 1;
        my $noWarningFiles = $#warningFiles + 1;
        my $noInfoFiles = $#infoFiles + 1;
        print "***Log files status : errors in $noErrorFiles file(s), warnings in $noWarningFiles file(s), informations in $noInfoFiles file(s)\n";
        print "***Log files are available in the [root/tmp] directory\n";
    }

}
