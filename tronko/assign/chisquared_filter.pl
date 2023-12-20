#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;

if ( scalar(@ARGV) < 5 ){
	print "./chisquared_filter.pl\n";
	print "ARGV[0]: Tronko results [REQUIRED]\n";
	print "ARGV[1]: Fasta file of forward reads containing (_F) designation [REQUIRED]\n";
	print "ARGV[2]: Fasta file of reverse reads containing (_R) designation [REQUIRED]\n";
    print "ARGV[3]: ASV forward file of paired reads [REQUIRED]\n";
    print "ARGV[4]: ASV reverse file of paired reads [REQUIRED]\n";
	print "ARGV[5]: distribution cutoff (default: 6.64)\n";
	print "ARGV[6]: divergence cutoff (default: 0.1)\n";
	exit;
}

if ( not defined $ARGV[5] ){
	$ARGV[5] = 6.64;
}
if ( not defined $ARGV[6] ){
	$ARGV[6] = 0.1;
}
my %forward_lengths = ();
my %forward_sequences = ();
my %reverse_lengths = ();
my %reverse_sequences = ();
my %asvf_lines = ();
my %asvr_lines = ();
my $read;

# define output files
my ($filename, $directories, $extension) = fileparse($ARGV[0], qr/\.[^.]*/);
my $tronko_output = $directories . $filename . "_filtered" . $extension;
open(my $TRONKO, '>', $tronko_output) || die("Cannot open file!");
($filename, $directories, $extension) = fileparse($ARGV[1], qr/\.[^.]*/);
my $fastaf_output = $directories . $filename . "_filtered" . $extension;
open(my $FASTAF, '>', $fastaf_output) || die("Cannot open file!");
($filename, $directories, $extension) = fileparse($ARGV[2], qr/\.[^.]*/);
my $fastar_output = $directories . $filename . "_filtered" . $extension;
open(my $FASTAR, '>', $fastar_output) || die("Cannot open file!");
($filename, $directories, $extension) = fileparse($ARGV[3], qr/\.[^.]*/);
my $asvf_output = $directories . $filename . "_filtered" . $extension;
open(my $ASVF, '>', $asvf_output) || die("Cannot open file!");
($filename, $directories, $extension) = fileparse($ARGV[4], qr/\.[^.]*/);
my $asvr_output = $directories . $filename . "_filtered" . $extension;
open(my $ASVR, '>', $asvr_output) || die("Cannot open file!");

open(FORWARD,$ARGV[1]) || die("Cannot open file!");
while(<FORWARD>){
	my $line = $_;
	chomp($line);
	if ($line =~ /^\>/){
		my @spl = split(/\>/,$line);
		$read = $spl[1];
	}else{
		my @spl = split(//,$line);
		$forward_lengths{$read} = scalar(@spl);
		$forward_sequences{$read} = $line;
	}
}
close(FORWARD);

open(REVERSE,$ARGV[2]) || die("Cannot open file!");
while(<REVERSE>){
	my $line = $_;
	chomp($line);
	if ($line =~ /^\>/){
		my @spl = split(/\>/,$line);
		$read = $spl[1];
	}else{
		my @spl = split(//,$line);
		$reverse_lengths{$read} = scalar(@spl);
		$reverse_sequences{$read} = $line;
	}
}
close(REVERSE);

open(ASVF,$ARGV[3]) || die("Cannot open file!");
while(<ASVF>){
	my $line = $_;
	chomp($line);
    if ( $line =~ /seq_number/ ){ 
        print $ASVF "$line\n";
        next; 
        }
	my @spl = split("\t",$line);
    $read=$spl[0];
    $asvf_lines{$read} = $line;
}
close(ASVF);

open(ASVR,$ARGV[4]) || die("Cannot open file!");
while(<ASVR>){
	my $line = $_;
	chomp($line);
    if ( $line =~ /seq_number/ ){ 
        print $ASVR "$line\n";
        next; 
        }
	my @spl = split("\t",$line);
    $read = $spl[0];
    $asvr_lines{$read} = $line;
}
close(ASVR);

my $eF;
my $eR;
my $chi_squared;
my $divergence;


print $TRONKO "Readname\tTaxonomic_Path\tScore\tForward_Mismatch\tReverse_Mismatch\tTree_Number\tNode_Number\n";
open(RESULTS,$ARGV[0]) || die("Cannot open file!");
while(<RESULTS>){
	my $line = $_;
	chomp($line);
	if ( $line =~ /^Readname/ ){ next; }
	my @spl = split("\t",$line);
	if ($spl[1] =~ /unassigned/ ){ next; }
	if ($spl[1] eq "NA" ){ next; }
	my $readname = $spl[0];
	my $readnamer = $readname;
	$readnamer =~ s/_F_/_R_/;
	if ($spl[3]==0 && $spl[4]==0){ 
        print $TRONKO "$spl[0]\t$spl[1]\t$spl[2]\t$spl[3]\t$spl[4]\t$spl[5]\t$spl[6]\n";
        print $ASVF "$asvf_lines{$readname}\n";
        print $ASVR "$asvr_lines{$readnamer}\n";
        print $FASTAF ">$readname\n";
        print $FASTAR ">$readnamer\n";
        print $FASTAF "$forward_sequences{$readname}\n";
        print $FASTAR "$reverse_sequences{$readnamer}\n";
        next; }
	my $mismatch_forward = $spl[3];
	my $mismatch_reverse = $spl[4];
	my $forward_length = length($forward_sequences{$readname});
	my $reverse_length = length($reverse_sequences{$readnamer});
	my $score = $spl[2];
	$eF = ($forward_length/($forward_length+$reverse_length))*($mismatch_forward + $mismatch_reverse);
	$eR = ($reverse_length/($forward_length+$reverse_length))*($mismatch_forward + $mismatch_reverse);
	$chi_squared = ($eF-$mismatch_forward)**2/$eF + ($eR-$mismatch_reverse)**2/$eR;
	$divergence = ($mismatch_forward + $mismatch_reverse) / ($forward_length + $reverse_length);
	if ( $chi_squared <= $ARGV[5] && $divergence <= $ARGV[6]){
		print $TRONKO "$spl[0]\t$spl[1]\t$spl[2]\t$spl[3]\t$spl[4]\t$forward_length\t$reverse_length\t$spl[5]\t$spl[6]\n";
        print $ASVF "$asvf_lines{$readname}\n";
        print $ASVR "$asvr_lines{$readnamer}\n";
        print $FASTAF ">$readname\n";
        print $FASTAR ">$readnamer\n";
        print $FASTAF "$forward_sequences{$readname}\n";
        print $FASTAR "$reverse_sequences{$readnamer}\n";
	}
}

$ASVR=~ s/paired_F/paired_R/g;
$FASTAR=~ s/paired_F/paired_R/g;

close(RESULTS);
close($TRONKO);
close($FASTAF);
close($FASTAR);
close($ASVF);
close($ASVR);
