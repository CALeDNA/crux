#!/usr/bin/perl
use strict;
use warnings;

my %remove = ();

open(TAX,$ARGV[0]) || die("cannot open file!");
my @spl = split(/\.tax\.tsv/,$ARGV[0]);
my $taxoutfile = $spl[0] . '_taxonomy2.txt';
open(TAXOUT,'>',$taxoutfile) || die("cannot open file!");
while(<TAX>){
	my $line = $_;
	chomp($line);
	my @spl = split(/\t/,$line);
	my $name = $spl[0];
	if ( $spl[1] =~ /uncultured/ || $spl[1] =~ /environmental/ || $spl[1] =~ /NA\;NA\;NA\;NA/ || $spl[1] =~ /unassigned/){
		$remove{$name} = 1;
	}else{
		print TAXOUT "$line\n";
	}
}
close(TAX);
close(TAXOUT);
my $acc;
open(FASTA,$ARGV[1]) || die("cannot open file!");
my @which = split(/\.fasta/,$ARGV[1]);
open(FASTAOUT, '>', $which[0] . '.fasta' . $which[1] . '_tmp') || die("cannot open file!");
while(<FASTA>){
	my $line = $_;
	chomp($line);
	my @spl = split(/\t/,$line);
	$acc = $spl[0];
	if ( not exists $remove{$acc} ){
		print FASTAOUT "$line\n";
	}
}
close(FASTA);
close(FASTAOUT);

open(PRUNE,'>',$which[0] . '_prune.txt') || die("cannot open file!");
foreach my $key (keys %remove){
	print PRUNE "$key\n";
}
