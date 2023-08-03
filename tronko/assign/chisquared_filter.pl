#!/usr/bin/perl
use strict;
use warnings;

if ( scalar(@ARGV) < 3 ){
	print "./chisquared_filter.pl\n";
	print "ARGV[0]: Tronko results [REQUIRED]\n";
	print "ARGV[1]: Fasta file of forward reads containing ( 1) designation [REQUIRED]\n";
	print "ARGV[2]: Fasta file of reverse reads containing ( 2) designation [REQUIRED]\n";
	print "ARGV[3]: distribution cutoff (default: 6.64)\n";
	print "ARGV[4]: divergence cutoff (default: 0.1)\n";
	exit;
}

if ( not defined $ARGV[3] ){
	$ARGV[3] = 6.64;
}
if ( not defined $ARGV[4] ){
	$ARGV[4] = 0.1;
}
my %forward_lengths = ();
my %reverse_lengths = ();
my $read;

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
	}
}
close(FORWARD);

open(REVERSE,$ARGV[2]) || die("Cannot open file!");
while(<REVERSE>){
	my $line = $_;
	chomp($line);
	if ($line =~ /^\>/){
		my @spl = split(/\>/,$line);
		@spl = split(/paired_R/,$spl[1]);
		$read = $spl[0] . "paired_F" . $spl[1];

	}else{
		my @spl = split(//,$line);
		$reverse_lengths{$read} = scalar(@spl);
	}
}
close(REVERSE);

my $eF;
my $eR;
my $chi_squared;
my $divergence;

print "Readname\tTaxonomic_Path\tScore\tForward_Mismatch\tReverse_Mismatch\tForward_length\tReverse_length\tTree_Number\tNode_Number\n";
open(RESULTS,$ARGV[0]) || die("Cannot open file!");
while(<RESULTS>){
	my $line = $_;
	chomp($line);
	if ( $line =~ /^Readname/ ){ next; }
	my @spl = split("\t",$line);
	if ($spl[1] =~ /unassigned/ ){ next; }
	if ($spl[1] eq "NA" ){ next; }
	my $readname = $spl[0];
	if ($spl[3]==0 && $spl[4]==0){ print "$spl[0]\t$spl[1]\t$spl[2]\t$spl[3]\t$spl[4]\t$forward_lengths{$readname}\t$reverse_lengths{$readname}\t$spl[5]\t$spl[6]\n"; next; }
	my $mismatch_forward = $spl[3];
	my $mismatch_reverse = $spl[4];
	my $forward_length = $forward_lengths{$readname};
	my $reverse_length = $reverse_lengths{$readname};
	my $score = $spl[2];
	$eF = ($forward_length/($forward_length+$reverse_length))*($mismatch_forward + $mismatch_reverse);
	$eR = ($reverse_length/($forward_length+$reverse_length))*($mismatch_forward + $mismatch_reverse);
	$chi_squared = ($eF-$mismatch_forward)**2/$eF + ($eR-$mismatch_reverse)**2/$eR;
	$divergence = ($mismatch_forward + $mismatch_reverse) / ($forward_length + $reverse_length);
	if ( $chi_squared <= $ARGV[3] && $divergence <= $ARGV[4]){
		print "$spl[0]\t$spl[1]\t$spl[2]\t$spl[3]\t$spl[4]\t$forward_length\t$reverse_length\t$spl[5]\t$spl[6]\n";
	}
}
close(RESULTS);