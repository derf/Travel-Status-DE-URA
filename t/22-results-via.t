#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use Encode qw(decode);
use File::Slurp qw(slurp);
use List::Util qw(first);
use Test::More tests => 23;

BEGIN {
	use_ok('Travel::Status::DE::ASEAG');
}
require_ok('Travel::Status::DE::ASEAG');

my $rawstr = slurp('t/in/aseag_20131223T132300');
my ($s, @results);

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
