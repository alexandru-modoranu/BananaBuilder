package step550;

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
my @stepName = ('step550', 'step560', 'step630');
my @builderSteps = ('BUILDGOAL','PRJ_PATH','PD_PATH','VERSION', 'TOOLCHAIN_PATH', 'NAME');

my $cwd;
my %stepHash;
my @asmSources;
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

    my $result;
    my $errorMsg;
    my $ldScriptName;

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

    foreach my $item (keys %stepHash)
    {
    	if (not (grep {$_ eq $item} @builderSteps))
    	{
    		logInfo("$stepName[0] - Generating \[$item\] ...");
    		$ldScriptName = $item;
    		open(OUTFILE, ">", "$cwd/obj/$item")
            and print(OUTFILE $stepHash{$item})
            and close(OUTFILE)
            and logResult('OK')
            or (logResult('NOK') and logError("Could not generate file $item."));

            last;
    	}
    }

    my @files = File::Find::Rule->file
                            	->name("*.o", "*.O") # search by file extensions
                            	->in("$cwd/obj");

    if ($#files < 0)
    {
    	logError("No object files found.");
    }

    logInfo("$stepName[0] - Starting linking for \[$stepHash{'NAME'}.elf\] ...");

    {
        local(*INFILE, $/);
        open(INFILE, "<", "$cwd/obj/ldopt.cfg") or logError("Cannot open file $cwd/obj/ldopt.cfg");
        $options = <INFILE>;
    }

    $options =~ s/\s+|\n+/ /g;
    $options =~ s/^\s+|\s+$//g;

	chdir "obj";

    $command = "$toolchainPath/arm-none-eabi-gcc -T$cwd/obj/$ldScriptName $options -Wl,-Map=$cwd/out/$stepHash{'NAME'}.map @files -o $cwd/out/$stepHash{'NAME'}.elf";

    {
        open my $log_fh, '>', "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.log" or logError("Cannot open file $cwd/tmp/$stepHash{'NAME'}.log");
        local *STDOUT = $log_fh;
        local *STDERR = $log_fh;

        print $log_fh "System command: $command\n\n" and close($log_fh);
        $result = system("$command 1>>$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.log 2>>&1");
    }

    {
        local(*INFILE, $/);
        open(INFILE, "<", "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.log") or logError("Cannot open file $cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.log");
        $errorMsg = <INFILE>;
    }

	if ($result == 0)
    {
        if ($errorMsg =~ /warning:/g)
        {
            rename "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.warn";
            logResult('WARNING');
        }
        else
        {
            rename "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.ok";
            logResult('OK');
        }
    }
    else
    {
        rename "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[0]\~$stepHash{'NAME'}.err";
        logResult('ERROR');
        chdir "..";
        logInfo("\n_______________ $stepName[0]\~$stepHash{'NAME'}.error _______________\n$errorMsg\n");
        exit;
    }

	logInfo("$stepName[1] - Creating listing in \[$stepHash{'NAME'}.lst\] ...");
    $command = "$toolchainPath/arm-none-eabi-objdump -S -D -Wl $cwd/out/$stepHash{'NAME'}.elf > $cwd/out/$stepHash{'NAME'}.lst";

    {
        # open my $log_fh, '>', "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.log" or logError("Cannot open file $cwd/tmp/$stepHash{'NAME'}.log");
        # local *STDOUT = $log_fh;
        # local *STDERR = $log_fh;

        # print $log_fh "System command: $command\n\n" and close($log_fh);
        $result = system("$command");#1>>$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.log 2>>&1");
    }

    # {
    #     local(*INFILE, $/);
    #     open(INFILE, "<", "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.log") or logError("Cannot open file $cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.log");
    #     $errorMsg = <INFILE>;
    # }

	if ($result == 0)
    {
        # if ($errorMsg =~ /warning:/g)
        # {
        #     rename "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.warn";
        #     logResult('WARNING');
        # }
        # else
        {
            # rename "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.ok";
            logResult('OK');
        }
    }
    else
    {
        # rename "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[1]\~$stepHash{'NAME'}.err";
        logResult('ERROR');
        chdir "..";
        logInfo("\n_______________ $stepName[1]\~$stepHash{'NAME'}.error _______________\n");#$errorMsg\n");
        exit;
    }

    logInfo("$stepName[2] - Creating binary in \[$stepHash{'NAME'}.bin\] ...");
    $command = "$toolchainPath/arm-none-eabi-objcopy -Obinary $cwd/out/$stepHash{'NAME'}.elf $cwd/out/$stepHash{'NAME'}.bin";

    {
        open my $log_fh, '>', "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.log" or logError("Cannot open file $cwd/tmp/$stepHash{'NAME'}.log");
        local *STDOUT = $log_fh;
        local *STDERR = $log_fh;

        print $log_fh "System command: $command\n\n" and close($log_fh);
        $result = system("$command 1>>$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.log 2>>&1");
    }

    {
        local(*INFILE, $/);
        open(INFILE, "<", "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.log") or logError("Cannot open file $cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.log");
        $errorMsg = <INFILE>;
    }

	if ($result == 0)
    {
        if ($errorMsg =~ /warning:/g)
        {
            rename "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.warn";
            logResult('WARNING');
        }
        else
        {
            rename "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.ok";
            logResult('OK');
        }
    }
    else
    {
        rename "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.log", "$cwd/tmp/$stepName[2]\~$stepHash{'NAME'}.err";
        logResult('ERROR');
        chdir "..";
        logInfo("\n_______________ $stepName[2]\~$stepHash{'NAME'}.error _______________\n$errorMsg\n");
        exit;
    }


    chdir "..";
}

########################################################################
###                       Subfunctions area                          ###
########################################################################
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
