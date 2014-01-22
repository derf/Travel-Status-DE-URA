#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use Encode qw(decode);
use List::Util qw(first);
use Test::More tests => 13;

BEGIN {
	use_ok('Travel::Status::DE::URA');
}
require_ok('Travel::Status::DE::URA');

my $s      = Travel::Status::DE::URA->new(
	ura_base  => 'file:t/in',
	ura_version => 1,
	datetime  => DateTime->new(
		year      => 2013,
		month     => 12,
		day       => 24,
		hour      => 12,
		minute    => 42,
		time_zone => 'Europe/Berlin'
	),
	hide_past => 0
);

isa_ok( $s,                          'Travel::Status::DE::URA' );

can_ok( $s, qw(errstr results) );

is( $s->errstr, undef, 'errstr is not set' );

# stop neither in name nor in results should return everything
my @results = $s->results;

is( @results, 16208, 'All departures parsed and returned' );

# hide_past => 1 should return nothing

@results = $s->results( hide_past => 1 );
is( @results, 0, 'hide_past => 1 returns nothing' );

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
$s = Travel::Status::DE::URA->new(
	ura_base  => 'file:t/in',
	ura_version => 1,
	datetime  => DateTime->new(
		year      => 2013,
		month     => 12,
		day       => 23,
		hour      => 12,
		minute    => 42,
		time_zone => 'Europe/Berlin'
	),
	hide_past => 0,
	stop      => 'Aachen Bushof',
);
@results = $s->results(
	stop  => 'Aachen Bushof',
);
is( @results, 375, '"Aachen Bushof" matches 375 stops in constructor' );
is( ( first { $_->stop ne 'Aachen Bushof' } @results ),
	undef, '"Aachen Bushof" only matches "Aachen Bushof" in constructor' );
