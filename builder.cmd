@echo off
REM %1 - Project Descriptor file
REM %2 - Build goal

cls

D:/prg/apps/perl/perl/bin/perl.exe -I %~dp0/lib/ %~dp0/lib/PdParser.pl %1 %2
