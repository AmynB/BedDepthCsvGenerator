#!/usr/bin/perl
use strict;
use warnings;

#Author: Amyn
#BAM-BED DamID Data Parser
#Must be placed in directory with BAM files and BED file
#Must be run on a UNIX/LINUX system

#Usage:
my $usage =<<"USAGE";
USAGE:

Command:
perl beddepth.pl [BED file] [-o Output File Name] [-c Control BAM files]

INPUT:
    In same directory as script:
        BED file
        BAM files

OUTPUT:
    Read Depth at each BED file interval into console/.csv file if in one BAM file
    read depth is 5 times higher than control.

Note:
    Requires Bedtools ver. 2.15.0 or higher installed.
    Requires Samtools.
    BED file parameter is required.
    Do not input file extension in the file name parameter.
    This script will attempt to create indexes for BAM files if not present.

USAGE

#initialize variables
my $control = "";
my $control2 = "";
my $controlcheck = 0;
my $commacontrol = "";
my $bamstring = "";
my $outputfile = "";
my $outputcheck = 0;

#obtain bam files and bed file from directory
opendir my $datadir, "." or die "Cannot open the directory - $!\n";

#Find bedfile
my $bedfile;
if ($ARGV[0] =~ /\.bed$/ && -e $ARGV[0]) {
    $bedfile = $ARGV[0];
} else {
    print "\n";
    print "Error: Invalid BED file.\n";
    print $usage;
    exit;
}

#parameter order:
#1) BED FILE
#2) OUTPUT FILE NAME
#3) FIRST CONTROL
#4) SECOND CONTROL
#***********************************************************
$outputfile = $ARGV[1];
$control = $ARGV[2];
$control2 = $ARGV[3];

#HARD-CODED LIMIT OF TWO CONTROLS - SUGGESTED TO EDIT THIS TO ALLOW FOR ANY NUMBER OF CONTROLS
$commacontrol = "$control,$control2";
#***********************************************************

#Save file data to array
my @totalfiles = readdir $datadir;
my @filelist = sort (grep {/\.bam$/} @totalfiles);

#***********************************************************
#GENERATES HEADER IN CSV - CONTROLS ONLY ; CHOOSE ONE OF THE FOLLOWING:

#IF YOU WANT CHROMOSOME LOCATION, LEAVE THE LINE BELOW UNCOMMENTED - NOTE: USING THIS OPTION IS NOT SUPPORTED IN SCRIPT PIPELINE
#my $firstline = "echo GATC_Site_Chr,Chr_Start_Pos,Chr_End_Pos$commacontrol";

#IF YOU DO NOT WANT CHROMOSOME LOCATION, LEAVE THE LINE BELOW UNCOMMENTED
my $firstline = "echo GATC_Site_Chr,$commacontrol";
#***********************************************************

#GENERATE HEADER IN CSV - NON-CONTROL FILES
foreach my $i (@filelist){
    next if ($i eq $control || $i eq $control2);
    $firstline .= ",$i";
}

#OUTPUT FILE NAME WITH EXTENSION
my $outputcsv = "$outputfile" . ".csv";


#***********************************************************
#COMMENT THE LINE BELOW IF YOU WANT TO PRINT HEADER TO CONSOLE INSTEAD OF TO FILE
$firstline .= "\> $outputcsv";
#***********************************************************

#PRINT FIRSTLINE TO FILE    
system($firstline);

#DELAY BY 5 SECONDS TO REDUCE STREAM-EDITING ERRORS
system("sleep 5s");

#***********************************************************
#GENERATING BAM FILE LIST FOR ENTRY INTO BEDTOOLS COMMAND - CONTROLS ONLY
$bamstring .= "$control $control2 ";
#***********************************************************

#makes sure indices exist, and if not it will create them
#CONTAINS A CHECK TO GENERATE INDEX FILES, BUT IT IS UNTESTED. IT IS SUGGESTED THAT THE USER MANUALLY GENERATE INDEX FILES.
#GENERATE INDEX FILES WITH THE COMMAND: samtools index [BAM FILE]

foreach my $indexcheck (@filelist){
    if (-e "$indexcheck.bai") {
        next if ($indexcheck eq $control || $indexcheck eq $control2);
        $bamstring .= "$indexcheck ";
    } else {
        system("samtools index $indexcheck");
        next if ($indexcheck eq $control || $indexcheck eq $control2);
        $bamstring .= "$indexcheck ";
    }
}

#initialize awk command parameter variable
my $awkstring;

#***********************************************************
#GENERATES STREAM EDITING AWK COMMAND ; CHOOSE ONE OF THE FOLLOWING:

#edited for one control
#$awkstring = q(awk -v OFS="," '{x=0; count++; for(i=4; i<=NF; i++){if ($i >= $4*5 && $i != $4 != 0 && $i-$4 > 10){x=1}} {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;}}} {x=0; sum=0; for(i=4; i<=NF; i++) sum=sum+$i; {if ($4 >= 10 && sum-$4 == 0){x=1}} {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;} sum=0; x=0; fflush(stdout)}}');

#edited for two controls
$awkstring = q(awk -v OFS="," '{x=0; count++; for(i=4; i<=NF; i++){if ((($i >= $4*5) && ($i != $4) && ($4 != 0)) || (($i >= $5*5) && ($i != $5) && ($5 != 0))){x=1}} {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;}}} {x=0; sum=0; for(i=4; i<=NF; i++) sum=sum+$i; {if ((($4 >= 10) && (sum-$4 == 0)) || (($5 >= 10) && (sum-$4-$5 == 0))){x=1}} {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;} sum=0; x=0; fflush(stdout)}}');
#             (1)           (2)              (3)                                                                                                                    (4)                                                                                     (5)                                                                                                                         (6)                                                                                               (7)                      
# ^ Function map for awk string guide below

#REQUIRES EDITING TO MAKE DYNAMIC FOR ANY NUMBER OF CONTROLS

my $AWK_STRING_GUIDE =<<'AWK';

This guide is to help facilitate understanding of the rather cluttered AWK string.

String component:
(1) awk -v OFS=","          
(2) '{x=0; count++;           
(3) for(i=4; i<=NF; i++){if ((($i >= $4*5) && ($i != $4) && ($4 != 0)) || (($i >= $5*5) && ($i != $5) && ($5 != 0))){x=1}}      
(4) {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;}}}         
(5) {x=0; sum=0; for(i=4; i<=NF; i++) sum=sum+$i; {if ((($4 >= 10) && (sum-$4 == 0)) || (($5 >= 10) && (sum-$4-$5 == 0))){x=1}}     
(6) {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;} sum=0; x=0;   
(7) fflush(stdout)}}'   

Function:
(1) Initializes awk statement. "-v" allows variables to be passed into awk. OFS="," establishes commas as column seperators.
(2) Initializes significance checker (x) and GATC site counter (count), and increments it in each iteration of the loop.
(3) Loops through columns 4 to end, if one number is four times the first control or second control, make x = 1.
(4) If x = 1, Report the read depth for each BAM file at that site. Change 'i=4' to 'i=2' to print loci.
(5) Loops through columns 4 to end, if first control or second control is significant (higher than 10), make x = 1.
(6) If x = 1, Report the read depth for each BAM file at that site. Change 'i=4' to 'i=2' to print loci.
(7) Refreshes output - REQUIRED

AWK

#***********************************************************

#compiles Bedtools multicov command
my $multicovcommand;


#***********************************************************
#GENERATES FINAL COMMAND ; CHOOSE ONE OF THE FOLLOWING:

#UNCOMMENT THE LINE BELOW IF YOU WANT TO PRINT HEADER TO FILE INSTEAD OF TO CONSOLE
$multicovcommand = qq/bedtools multicov -D -bams $bamstring -bed $bedfile | $awkstring \> $outputcsv/;

#UNCOMMENT THE LINE BELOW IF YOU WANT TO PRINT HEADER TO CONSOLE INSTEAD OF TO FILE
#$multicovcommand = qq/bedtools multicov -D -bams $bamstring -bed $bedfile | $awkstring/;

#***********************************************************

#replace all spaces with commas
$bamstring =~ s/ /,/g;

#PRINTS COMMAND TO CONSOLE - CHECK FOR ERRORS
print $multicovcommand, "\n";

#Run command
system($multicovcommand);

#Close directory
closedir $datadir;
