#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor;
my (@failed, @passed, @knownbad, @missing);
my $regression = 0;
my $upstream = 0;
my $coverage = 0;

GetOptions(
	'regression' => \$regression,
	'upstream' => \$upstream,
    'coverage' => \$coverage
);

if ($coverage) { $ENV{SILE_COVERAGE} = 1}

my @specifics = @ARGV;

if ($regression) {
	my $exit = 0;
	for (@specifics ? @specifics : <tests/*.sil>) {
		my $expectation = $_; $expectation =~ s/\.sil$/\.expected/;
		my $knownbad;
		if (-f $expectation) {
			# Only run regression tests for upstream bugs if specifically asked
			if ($_ =~ /_upstream\.sil/) {
				next if !$upstream;
			# Only test OS specific regressions on their respective OSes
			} elsif ($_ =~ /_\w+\.sil/) {
				next if ($_ !~ /_$^O\.sil/) ;
			}
			print "### Regression testing $_\n";
			my $out = $_; $out =~ s/\.sil$/\.actual/;
			if (!system("grep KNOWNBAD $_ >/dev/null")) {
				$knownbad = 1;
			}
			exit $? >> 8 if system qq!./sile -e 'require("core/debug-output")' $_ > $out!;
			if (system("diff -U0 $expectation $out")) {
				push ($knownbad ? \@knownbad : \@failed, $_);
			} else { push $knownbad ? \@failed: \@passed, $_ }
		} else {
			push \@missing, $_;
		}
	}
	if (@passed){
		print "\n",color("green"), "Passing tests:",color("reset");
		print "\n • ",join(", ", @passed),"\n";
	}
	if (@failed) {
		print "\n",color("red"), "Failed tests:\n",color("reset");
		for (@failed) { print " • ",$_,"\n"}
	}
	if (@knownbad){
		print "\n",color("yellow"), "Known bad tests:",color("reset");
		print "\n • ",join(", ", @knownbad),"\n";
	}
	if (@missing){
		print "\n",color("cyan"),"Tests missing expectations:",color("reset");
		print "\n • ",join(", ", @missing),"\n";
	}
} else {
	for (<examples/*.sil>, "documentation/sile.sil") {
		next if /macros.sil/;
		print "### Compiling $_\n";
		exit $? >> 8 if system("./sile", $_);
	}
}
if (@failed) {
	exit 1;
}
