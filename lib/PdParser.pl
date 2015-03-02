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
    
}
