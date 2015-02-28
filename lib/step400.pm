package step400;

use strict;
use warnings;
use File::Find::Rule;
use File::Copy;
use File::Spec;
use File::Path;
use Cwd;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = 1.00;

@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(executeGoal);
%EXPORT_TAGS = (Both => [qw(&executeGoal)]);

=head1 NAME

step400 - Module to check project consistency, update and removal of project files

=head1 DESCRIPTION

This module provides the means to check the project directory structure and check consistency

=cut
my $stepName = 'step400';
my @builderSteps = ('BUILDGOAL','PRJ_PATH','PD_PATH','VERSION', 'TOOLCHAIN_PATH', 'NAME');

my $cwd;
my %stepHash;
my @cSources;
my $options;
my $command;
my $toolchainPath;
my %sourceFiles;

########################################################################
###                       Module entry point                         ###
########################################################################
sub executeGoal
{
    shift;
    %stepHash = %{$_[0]};

    if (exists $stepHash{'PRJ_PATH'})
    {
        $cwd = $stepHash{'PRJ_PATH'};
    }
    else
    {
        $cwd = getcwd();
    }

    if (exists $stepHash{'TOOLCHAIN_PATH'})
    {
        $toolchainPath = $stepHash{'TOOLCHAIN_PATH'};
    }
    else
    {
        logError("No toolchain path defined.");
    }

    if (exists $stepHash{'C_SOURCES'})
    {
        @cSources = split(/\s+/, $stepHash{'C_SOURCES'});
    }
    else
    {
        logError("No C sources defined.");
    }

    logInfo("$stepName - Starting compilation for [C_SOURCES]\n");

    {
        local(*INFILE, $/);
        open(INFILE, "<", "$cwd/obj/ccopt.cfg") or logError("Cannot open file $cwd/obj/ccopt.cfg");
        $options = <INFILE>;
    }

    $options =~ s/\s+|\n+/ /g;
    $options =~ s/^\s+|\s+$//g;

    $command = "$toolchainPath/arm-none-eabi-gcc -c -I$cwd/obj -I$cwd/src $options";

    buildFileIndex(\@cSources);

    chdir "obj";
    foreach my $file (@cSources)
    {
        my $expandedCmd = $command . " $cwd/src/$file";
        my ($noExtFile) = $file =~ /(.+)\..*/;
        my $result;
        my $errorMsg;

        logInfo("Compiling $noExtFile\.o ...");

        {
            open my $log_fh, '>', "$cwd/tmp/$stepName\~$noExtFile.log" or logError("Cannot open file $cwd/tmp/$stepName\~$noExtFile.log");
            local *STDOUT = $log_fh;
            local *STDERR = $log_fh;

            print $log_fh "System command: $expandedCmd\n\n" and close($log_fh);
            $result = system("$expandedCmd 1>>$cwd/tmp/$stepName\~$noExtFile.log 2>>&1");
        }

        {
            local(*INFILE, $/);
            open(INFILE, "<", "$cwd/tmp/$stepName\~$noExtFile.log") or logError("Cannot open file $cwd/tmp/$stepName\~$noExtFile.log");
            $errorMsg = <INFILE>;
        }

        {
            foreach my $key (keys %sourceFiles)
            {
                $errorMsg =~ s/$key/$sourceFiles{$key}/g;
            }

            local(*OUTFILE, $/);
            open(OUTFILE, ">", "$cwd/tmp/$stepName\~$noExtFile.log") or logError("Cannot open file $cwd/tmp/$stepName\~$noExtFile.log");
            print OUTFILE $errorMsg;
        }

        if ($result == 0)
        {
            if ($errorMsg =~ /warning:/g)
            {
                rename "$cwd/tmp/$stepName\~$noExtFile.log", "$cwd/tmp/$stepName\~$noExtFile.warn";
                logResult('WARNING');
            }
            else
            {
                rename "$cwd/tmp/$stepName\~$noExtFile.log", "$cwd/tmp/$stepName\~$noExtFile.ok";
                logResult('OK');
            }
        }
        else
        {
            rename "$cwd/tmp/$stepName\~$noExtFile.log", "$cwd/tmp/$stepName\~$noExtFile.err";
            logResult('ERROR');
            chdir "..";
            logInfo("\n_______________ $stepName\~$noExtFile.error _______________\n$errorMsg\n");
            exit;
        }

    }
    chdir "..";
}

########################################################################
###                       Subfunctions area                          ###
########################################################################
sub buildFileIndex
{
    my ($extensionList) = @_;
    my @extList = @{$extensionList};
    my @dirFiltList = ('obj', 'src');

    my @files = File::Find::Rule->file
                         ->name(@extList) # search by file extensions
                         ->in($cwd);

    foreach my $outerIndex (0..$#files)
    {
        my ($fileName) = $files[$outerIndex] =~ /.+[\/|\\](.+)/g;

        if ($files[$outerIndex] =~ /.+(src|obj)[\/|\\]$fileName/g)
        {
            foreach my $innerIndex (0..$#files)
            {
                if ($files[$innerIndex] =~ /.+(?!(src|obj))[\/|\\]$fileName/g)
                {
                    $sourceFiles{$files[$outerIndex]} = $files[$innerIndex];
                    last;
                }                
            }             
        }
    }    
}

sub logInfo
{
    my $info = shift;

    print("$info");
}

sub logResult
{
    my $result = shift;

    print("[$result]\n");
}

sub logError
{
    my $error = shift;

    print "ERROR: $error\n";
    exit;
}

1;
