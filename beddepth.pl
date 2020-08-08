#!/usr/bin/perl
use strict;
use warnings;

#Author: ab-src
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

opendir my $datadir, "." or die "Cannot open the directory - $!\n";

my $bedfile;
if ($ARGV[0] =~ /\.bed$/ && -e $ARGV[0]) {
    $bedfile = $ARGV[0];
} else {
    print "\n";
    print "Error: Invalid BED file.\n";
    print $usage;
    exit;
}

$outputfile = $ARGV[1];
$control = $ARGV[2];
$control2 = $ARGV[3];

$commacontrol = "$control,$control2";

my @totalfiles = readdir $datadir;
my @filelist = sort (grep {/\.bam$/} @totalfiles);

my $firstline = "echo GATC_Site_Chr,$commacontrol";

foreach my $i (@filelist){
    next if ($i eq $control || $i eq $control2);
    $firstline .= ",$i";
}

my $outputcsv = "$outputfile" . ".csv";

$firstline .= "\> $outputcsv";
 
system($firstline);

system("sleep 5s");

$bamstring .= "$control $control2 ";

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

my $awkstring;

$awkstring = q(awk -v OFS="," '{x=0; count++; for(i=4; i<=NF; i++){if ((($i >= $4*5) && ($i != $4) && ($4 != 0)) || (($i >= $5*5) && ($i != $5) && ($5 != 0))){x=1}} {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;}}} {x=0; sum=0; for(i=4; i<=NF; i++) sum=sum+$i; {if ((($4 >= 10) && (sum-$4 == 0)) || (($5 >= 10) && (sum-$4-$5 == 0))){x=1}} {if (x == 1){ s = "GATC_Site_"count"_"$1; for(i=4; i<=NF; i++) s = s ","$i; print s;} sum=0; x=0; fflush(stdout)}}');

my $multicovcommand;
$multicovcommand = qq/bedtools multicov -D -bams $bamstring -bed $bedfile | $awkstring \> $outputcsv/;
$bamstring =~ s/ /,/g;
print $multicovcommand, "\n";
system($multicovcommand);
closedir $datadir;
