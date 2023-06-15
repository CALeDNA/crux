#!/usr/bin/perl
use strict;
use warnings;

open(FASTA,$ARGV[0]) || die("Cannot open file!");
while(<FASTA>){
	my $line = $_;
	chomp($line);
	if ( $line =~ /^\>/ ){ 
		print "$line\n";
		next; 
	}
	my @spl = split(//,$line);
	for(my $i=0; $i<scalar(@spl); $i++){
		if ($spl[$i] ne "A" and $spl[$i] ne "C" and $spl[$i] ne "T" and $spl[$i] ne "G" and $spl[$i] ne "-" and $spl[$i] ne "N"){
			print "N";
		}else{
			print "$spl[$i]";
		}
	}
	print "\n";
	#if ( $line =~ /^(?:?![ACGTN\-]*)*\$/){
	#if ( $line !~ /[ACGTN]*[\-]*/ ){
	#	print "$line\n";
	#}
}
close(FASTA);
