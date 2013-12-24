#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use Encode qw(decode);
use File::Slurp qw(slurp);
use List::Util qw(first);
use Test::More tests => 5;

BEGIN {
	use_ok('Travel::Status::DE::ASEAG');
}
require_ok('Travel::Status::DE::ASEAG');

my $rawstr = slurp('t/in/aseag_20131223T132300');
my $s      = Travel::Status::DE::ASEAG->new_from_raw(
	raw_str   => $rawstr,
	hide_past => 0
);

# fuzzy matching: bushof should return Aachen Bushof, Eschweiler Bushof,
# Eupon Bushof

my @fuzzy = $s->get_stop_by_name('bushof');

is_deeply(\@fuzzy, ['Aachen Bushof', 'Eschweiler Bushof', 'Eupen Bushof'],
'fuzzy match for "bushof" works');

# fuzzy matching: whitespaces work

@fuzzy = $s->get_stop_by_name('Aachen Bushof');

is_deeply(\@fuzzy, ['Aachen Bushof'],
'fuzzy match with exact name "Aachen Bushof" works');

# fuzzy matching: exact name only matches one, even though longer alternatives
# exist

@fuzzy = $s->get_stop_by_name('brand');

is_deeply(\@fuzzy, ['Brand'],
'fuzzy match with exact name "brand" works');
