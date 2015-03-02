package step000;

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
%EXPORT_TAGS = (Both => [qw(&executeGoal &getSourceFileTree)]);

=head1 NAME

step000 - Module to check project consistency, update and removal of project files

=head1 DESCRIPTION

This module provides the means to check the project directory structure and check consistency

=cut
my $stepName = 'step000';
my @foldersToCheck = ('obj', 'out', 'src', 'tmp');
my %dispatchTable = ( "clean"   => \&cleanProject,
                      "build"   => \&buildProject,
                      "rebuild" => \&rebuildProject);
my @builderSteps = ('BUILDGOAL','PRJ_PATH','PD_PATH','VERSION', 'TOOLCHAIN_PATH', 'NAME');

my $cwd;
my $timeStamp;
my $toolchainPath;
my %stepHash;
my %sourceFiles;

########################################################################
###                       Module entry point                         ###
########################################################################
sub executeGoal
{
    shift;
    %stepHash = %{$_[0]};

    printBuildInfo();
    checkAndCreateProjectTree();

    $dispatchTable{$stepHash{'BUILDGOAL'}}->();
}

sub getSourceFileTree
{
    return %sourceFiles;
}

########################################################################
###                       Subfunctions area                          ###
########################################################################
sub printBuildInfo
{
    my $dateTimeString = localtime();

    $toolchainPath = $stepHash{'TOOLCHAIN_PATH'};

    if (exists $stepHash{'PRJ_PATH'})
    {
        $cwd = $stepHash{'PRJ_PATH'};
    }
    else
    {
        $cwd = getcwd();
    }

    logInfo("Build process started on \[$dateTimeString\]\n");
    logInfo("____________________________________________________________\n");
    logInfo("BananaBuilder - Toolset location : $stepHash{'LOCAL'}\n");
    logInfo("BananaBuilder - Project location : $cwd\n");
    logInfo("BananaBuilder - Toolchain location : $toolchainPath\n");
    logInfo("___________________ Project Information ____________________\n");
    logInfo("BananaBuilder - Platform : $stepHash{'PLATFORM'}\n");
    logInfo("BananaBuilder - PD file : $stepHash{'PD_PATH'}\n");
    logInfo("________________ Execution of Goal <$stepHash{'BUILDGOAL'}> _________________\n");
}

sub cleanProject
{
    logInfo("$stepName - Cleaning project directory...\n");
    foreach my $folder (@foldersToCheck)
    {
        rmtree($folder);
        mkdir($folder);
    }
}

sub buildProject
{
    buildLog();
    buildFileIndex(\$stepHash{'EXT_FILTER'}, \$stepHash{'DIR_FILTER'});
}

sub rebuildProject
{
    cleanProject();
    buildProject();
}

sub checkAndCreateProjectTree
{
    foreach my $folder (@foldersToCheck)
    {
        if (-e $folder)
        {
            # is a file
            unlink $folder;
            mkdir($folder);
        }
        elsif (-d $folder)
        {
            # is a directory
        }
        else
        {
            # does not exist
            mkdir($folder);
        }
    }
}

sub buildLog
{
    # Find out the last build timestamp
    logInfo("$stepName - Checking for the build log file ...");
    if (-f "$cwd/tmp/build.log")
    {
        # Plain file exists
        $timeStamp = (stat("$cwd/tmp/build.log"))[9];
        logResult('OK');

        # Update build log
        logInfo("$stepName - Updating build log ...")
        and open(BUILDLOG, '>', "$cwd/tmp/build.log")
        and close(BUILDLOG)
        and logResult('OK')
        or (logResult('NOK') and logError("Could not open buildlog!"));
    }
    else
    {
        # Plain file does not exist
        $timeStamp = 0;
        logResult('NOK');

        # Create build log
        logInfo("$stepName - Creating build log ...")
        and open(BUILDLOG, '>', "$cwd/tmp/build.log")
        and close(BUILDLOG)
        and logResult('OK')
        or (logResult('NOK') and logError("Could not create buildlog!"));
    }
}

sub buildFileIndex
{
    my ($extensionList, $dirFilterList) = @_;
    my @extList = split(/\s+/, ${$extensionList});
    my @dirFiltList = split(/\s+/, ${$dirFilterList});

    push @dirFiltList, @foldersToCheck;

    my @files = File::Find::Rule->file
                         ->name(@extList) # search by file extensions
                         ->in($cwd);
    logInfo("$stepName - Checking sources list ...");
    foreach my $file (@files)
    {
        my ($fileName) = $file =~ /.+[\/|\\](.+)/g;

        push(@{$sourceFiles{$fileName}}, $file);
    }

    foreach my $item (keys %sourceFiles)
    {

        if ($#{$sourceFiles{$item}} > 1)
        {            
            logResult('NOK');

            # build error message
            my $errorMsg = "Duplicate file <$item>\n    File locations:\n";

            foreach my $itemInItem (@{$sourceFiles{$item}})
            {
                $errorMsg = $errorMsg . "    $itemInItem\n";
            }

            $errorMsg = $errorMsg . "\n[Solution]:\n1. Filter the folders containing duplicates with DIR_FILTER.\n2. Rename the duplicate files.\n\n";
            logInfo($errorMsg);
            logError("Duplicate files found!\n");
        }
        elsif ($#{$sourceFiles{$item}} == 1)
        {
            my $skip = 0;

            foreach my $itemInItem (@{$sourceFiles{$item}})
            {
                my ($shortFilePath) = $itemInItem =~ /$cwd([\/|\\].*)/;

                foreach my $dirPath (@foldersToCheck)
                {
                    if ($shortFilePath =~ /$dirPath/)
                    {
                        $skip = 1;
                        last;
                    }
                }
            }

            if ($skip == 0)
            {
                logResult('NOK');

                # build error message
                my $errorMsg = "Duplicate file <$item>\n    File locations:\n";

                foreach my $itemInItem (@{$sourceFiles{$item}})
                {
                    $errorMsg = $errorMsg . "    $itemInItem\n";
                }

                $errorMsg = $errorMsg . "\n[Solution]:\n1. Filter the folders containing duplicates with DIR_FILTER.\n2. Rename the duplicate files.\n\n";
                logInfo($errorMsg);
                logError("Duplicate files found!\n");
            }
        }
        else
        {
            # Do nothing
        }
    }

    foreach my $file (@files)
    {
        if ($timeStamp < (stat($file))[9])
        {
            my ($shortFilePath) = $file =~ /$cwd([\/|\\].*)/;
            my $dontWrite = 0;

            foreach my $dirPath (@dirFiltList)
            {
                if ($shortFilePath =~ /$dirPath/)
                {
                    $dontWrite = 1;
                    last;
                }
            }

            if ($dontWrite == 0)
            {
                copy $file => "$cwd/src" or (logResult('NOK') and logError("Could not copy files"));
            }
        }
    }


    logResult('OK');
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
