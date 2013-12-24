#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use Encode qw(decode);
use File::Slurp qw(slurp);
use List::Util qw(first);
use Test::More tests => 38;

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

# hide_past => 1 should return nothing

@results = $s->results( hide_past => 1 );
is( @results, 0, 'hide_past => 1 returns nothing' );

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

# exact matching: bushof should match nothing

@results = $s->results(
	stop  => 'bushof',
);
is( @results, 0, '"bushof" matches nothing' );

@results = $s->results(
	stop  => 'aachen bushof',
);
is( @results, 0, 'matching is case-sensitive' );

# exact matching: Aachen Bushof should work
@results = $s->results(
	stop  => 'Aachen Bushof',
);

is( @results, 375, '"Aachen Bushof" matches 375 stops' );
is( ( first { $_->stop ne 'Aachen Bushof' } @results ),
	undef, '"Aachen Bushof" only matches "Aachen Bushof"' );

# exact matching: also works in constructor
$s = Travel::Status::DE::ASEAG->new_from_raw(
	raw_str   => $rawstr,
	hide_past => 0,
	stop      => 'Aachen Bushof',
);
@results = $s->results(
	stop  => 'Aachen Bushof',
);
is( @results, 375, '"Aachen Bushof" matches 375 stops in constructor' );
is( ( first { $_->stop ne 'Aachen Bushof' } @results ),
	undef, '"Aachen Bushof" only matches "Aachen Bushof" in constructor' );

# via filter in ->results, implicit route_after

$s = Travel::Status::DE::ASEAG->new_from_raw(
	raw_str   => $rawstr,
	hide_past => 0,
	stop      => 'Aachen Bushof',
);
@results = $s->results( via => 'Finkensief' );

is( @results, 5, '"Aachen Bushof" via_after Finkensief' );
ok( ( first { $_->line == 25 } @results ),
	'"Aachen Bushof" via_after "Brand" contains line 25' );
ok(
	( first { $_->destination eq 'Stolberg Mühlener Bf.' } @results ),
	'"Aachen Bushof" via_after "Brand" contains dest Stolberg Muehlener Bf.'
);
ok( ( first { $_->line == 1 } @results ),
	'"Aachen Bushof" via_after "Brand" contains line 1' );
ok(
	( first { $_->destination eq 'Schevenhütte' } @results ),
	'"Aachen Bushof" via_after "Brand" contains dest Schevenhuette'
);
is( ( first { $_->line != 1 and $_->line != 25 } @results ),
	undef, '"Aachen Bushof" via_after "Brand" does not contain other lines' );
is(
	(
		first {
			$_->destination ne 'Stolberg Mühlener Bf.'
			  and $_->destination ne 'Schevenhütte';
		}
		@results
	),
	undef,
	'"Aachen Bushof" via_after "Brand" does not contain other dests'
);

# via filter in ->results, explicit route_after

$s = Travel::Status::DE::ASEAG->new_from_raw(
	raw_str   => $rawstr,
	hide_past => 0,
	stop      => 'Aachen Bushof',
);
@results = $s->results(
	via         => 'Finkensief',
	full_routes => 'after'
);

is( @results, 5, '"Aachen Bushof" via_after Finkensief' );
ok( ( first { $_->line == 25 } @results ),
	'"Aachen Bushof" via_after "Brand" contains line 25' );
ok(
	( first { $_->destination eq 'Stolberg Mühlener Bf.' } @results ),
	'"Aachen Bushof" via_after "Brand" contains dest Stolberg Muehlener Bf.'
);
ok( ( first { $_->line == 1 } @results ),
	'"Aachen Bushof" via_after "Brand" contains line 1' );
ok(
	( first { $_->destination eq 'Schevenhütte' } @results ),
	'"Aachen Bushof" via_after "Brand" contains dest Schevenhuette'
);
is( ( first { $_->line != 1 and $_->line != 25 } @results ),
	undef, '"Aachen Bushof" via_after "Brand" does not contain anything else' );
is(
	(
		first {
			$_->destination ne 'Stolberg Mühlener Bf.'
			  and $_->destination ne 'Schevenhütte';
		}
		@results
	),
	undef,
	'"Aachen Bushof" via_after "Brand" does not contain other dests'
);

# via filter in ->results, explicit route_before

$s = Travel::Status::DE::ASEAG->new_from_raw(
	raw_str   => $rawstr,
	hide_past => 0,
	stop      => 'Aachen Bushof',
);
@results = $s->results(
	via         => 'Finkensief',
	full_routes => 'before'
);

is( @results, 5, '"Aachen Bushof" via_before Finkensief' );
ok( ( first { $_->line == 25 } @results ),
	'"Aachen Bushof" via_after "Brand" contains line 25' );
ok(
	( first { $_->destination eq 'Vaals Heuvel' } @results ),
	'"Aachen Bushof" via_after "Brand" contains dest Vaals Heuvel'
);
ok( ( first { $_->line == 1 } @results ),
	'"Aachen Bushof" via_after "Brand" contains line 1' );
ok(
	( first { $_->destination eq 'Lintert Friedhof' } @results ),
	'"Aachen Bushof" via_after "Brand" contains dest Lintert Friedhof'
);
is( ( first { $_->line != 1 and $_->line != 25 } @results ),
	undef, '"Aachen Bushof" via_after "Brand" does not contain anything else' );
is(
	(
		first {
			$_->destination ne 'Vaals Heuvel'
			  and $_->destination ne 'Lintert Friedhof';
		}
		@results
	),
	undef,
	'"Aachen Bushof" via_after "Brand" does not contain other dests'
);
