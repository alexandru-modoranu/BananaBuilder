package step010;

use strict;
use warnings;
use File::Find::Rule;
use File::Copy;
use File::Spec;
use File::Path;
use Cwd;
use List::Util;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = 1.00;

@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(executeGoal);
%EXPORT_TAGS = (Both => [qw(&executeGoal)]);

=head1 NAME

step010 - Module to check project consistency, update and removal of project files

=head1 DESCRIPTION

This module provides the means to check the project directory structure and check consistency

=cut
my $stepName = 'step010';
my @builderSteps = ('BUILDGOAL','PRJ_PATH','PD_PATH','VERSION', 'TOOLCHAIN_PATH', 'NAME');

my $cwd;
my %stepHash;

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

    foreach my $item (keys %stepHash)
    {
        if (not (grep {$_ eq $item} @builderSteps))
        {
            logInfo("$stepName - Generating $item ...");
            open(OUTFILE, ">", "$cwd/obj/$item")
            and print(OUTFILE $stepHash{$item})
            and close(OUTFILE)
            and logResult('OK')
            or (logResult('NOK') and logError("Could not generate file $item."));
        }
    }

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
