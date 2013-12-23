#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use Encode qw(decode);
use File::Slurp qw(slurp);
use List::Util qw(first);
use Test::More tests => 18;

BEGIN {
	use_ok('Travel::Status::DE::ASEAG');
}
require_ok('Travel::Status::DE::ASEAG');

my $rawstr = slurp('t/in/aseag_20131223T132300');
my $s      = Travel::Status::DE::ASEAG->new_from_raw(
	raw_str   => $rawstr,
	hide_past => 0
);

isa_ok( 'Travel::Status::DE::ASEAG', 'Travel::Status::DE::URA' );
isa_ok( $s,                          'Travel::Status::DE::ASEAG' );

can_ok( $s, qw(errstr results) );

is( $s->errstr, undef, 'errstr is not set' );

# stop neither in name nor in results should return everything
my @results = $s->results;

is( @results, 16208, 'All departures parsed and returned' );

# fuzzy matching: bushof should return Aachen Bushof and Eschweiler Bushof
# (459 results)

@results = $s->results( stop => 'bushof' );

is( @results, 459, '"bushof" fuzzy-matches 459 stops' );
ok(
	( first { $_->stop eq 'Aachen Bushof' } @results ),
	'"bushof" fuzzy-matches "Aachen Bushof"'
);
ok(
	( first { $_->stop eq 'Eschweiler Bushof' } @results ),
	'"bushof" fuzzy-matches "Eschweiler Bushof"'
);
ok(
	( first { $_->stop eq 'Eupen Bushof' } @results ),
	'"bushof" fuzzy-matches "Eupen Bushof"'
);
is(
	(
		first {
			not(   $_->stop eq 'Aachen Bushof'
				or $_->stop eq 'Eschweiler Bushof'
				or $_->stop eq 'Eupen Bushof' );
		}
		@results
	),
	undef,
	'"bushof" does not match anything else'
);

# exact matching: bushof should match nothing

@results = $s->results(
	stop  => 'bushof',
	fuzzy => 0
);
is( @results, 0, '"bushof" matches nothing' );

@results = $s->results(
	stop  => 'aachen bushof',
	fuzzy => 0
);
is( @results, 0, 'matching is case-sensitive' );

# exact matching: Aachen Bushof should work
@results = $s->results(
	stop  => 'Aachen Bushof',
	fuzzy => 0
);

is( @results, 375, '"Aachen Bushof" matches 375 stops' );
is( ( first { $_->stop ne 'Aachen Bushof' } @results ),
	undef, '"Aachen Bushof" only matches "Aachen Bushof"' );

# exact matching: also works in constructor
$s = Travel::Status::DE::ASEAG->new_from_raw(
	raw_str   => $rawstr,
	hide_past => 0,
	stop      => 'Aachen Bushof',
	fuzzy     => 0
);
@results = $s->results(
	stop  => 'Aachen Bushof',
	fuzzy => 0
);
is( @results, 375, '"Aachen Bushof" matches 375 stops in constructor' );
is( ( first { $_->stop ne 'Aachen Bushof' } @results ),
	undef, '"Aachen Bushof" only matches "Aachen Bushof" in constructor' );
