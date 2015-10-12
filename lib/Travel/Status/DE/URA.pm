package Travel::Status::DE::URA;

use strict;
use warnings;
use 5.010;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

our $VERSION = '0.04';

use Carp qw(confess cluck);
use DateTime;
use Encode qw(encode decode);
use List::MoreUtils qw(firstval none uniq);
use LWP::UserAgent;
use Text::CSV;
use Travel::Status::DE::URA::Result;
use Travel::Status::DE::URA::Stop;

sub new {
	my ( $class, %opt ) = @_;

	my %lwp_options = %{ $opt{lwp_options} // { timeout => 10 } };

	my $ua = LWP::UserAgent->new(%lwp_options);
	my $response;

	if ( not( $opt{ura_base} and $opt{ura_version} ) ) {
		confess('ura_base and ura_version are mandatory');
	}

	my $self = {
		datetime => $opt{datetime}
		  // DateTime->now( time_zone => 'Europe/Berlin' ),
		developer_mode => $opt{developer_mode},
		ura_base       => $opt{ura_base},
		ura_version    => $opt{ura_version},
		full_routes    => $opt{calculate_routes} // 0,
		hide_past      => $opt{hide_past} // 1,
		stop           => $opt{stop},
		via            => $opt{via},
		post           => {
			ReturnList =>
			  'lineid,linename,directionid,destinationtext,vehicleid,'
			  . 'tripid,estimatedtime,stopid,stoppointname'
		},
	};

	$self->{ura_instant_url}
	  = $self->{ura_base} . '/instant_V' . $self->{ura_version};

	bless( $self, $class );

	$ua->env_proxy;

	if ( substr( $self->{ura_instant_url}, 0, 5 ) ne 'file:' ) {
		$response = $ua->post( $self->{ura_instant_url}, $self->{post} );
	}
	else {
		$response = $ua->get( $self->{ura_instant_url} );
	}

	if ( $response->is_error ) {
		$self->{errstr} = $response->status_line;
		return $self;
	}

	$self->{raw_str} = $response->decoded_content;

	if ( $self->{developer_mode} ) {
		say $self->{raw_str};
	}

	# Fix encoding in case we're running through test files
	if ( substr( $self->{ura_instant_url}, 0, 5 ) eq 'file:' ) {
		$self->{raw_str} = encode( 'UTF-8', $self->{raw_str} );
	}
	$self->parse_raw_data;

	return $self;
}

sub parse_raw_data {
	my ($self) = @_;
	my $csv = Text::CSV->new( { binary => 1 } );

	for my $dep ( split( /\r\n/, $self->{raw_str} ) ) {
		$dep =~ s{^\[}{};
		$dep =~ s{\]$}{};

		# first field == 4 => version information, no departure
		if ( substr( $dep, 0, 1 ) != 4 ) {
			$csv->parse($dep);
			my @fields = $csv->fields;
			push( @{ $self->{raw_list} }, \@fields );
			for my $i ( 1, 6 ) {
				$fields[$i] = encode( 'UTF-8', $fields[$i] );
			}
			push( @{ $self->{stop_names} }, $fields[1] );
		}
	}

	@{ $self->{stop_names} } = uniq @{ $self->{stop_names} };

	return $self;
}

sub get_stop_by_name {
	my ( $self, $name ) = @_;

	my $nname = lc($name);
	my $actual_match = firstval { $nname eq lc($_) } @{ $self->{stop_names} };

	if ($actual_match) {
		return $actual_match;
	}

	return ( grep { $_ =~ m{$name}i } @{ $self->{stop_names} } );
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub results {
	my ( $self, %opt ) = @_;
	my @results;

	my $full_routes = $opt{calculate_routes} // $self->{full_routes} // 0;
	my $hide_past   = $opt{hide_past}        // $self->{hide_past}   // 1;
	my $stop        = $opt{stop}             // $self->{stop};
	my $via         = $opt{via}              // $self->{via};

	my $dt_now = $self->{datetime};
	my $ts_now = $dt_now->epoch;

	if ($via) {
		$full_routes = 1;
	}

	for my $dep ( @{ $self->{raw_list} } ) {

		my (
			$u1, $stopname, $stopid,    $lineid, $linename,
			$u2, $dest,     $vehicleid, $tripid, $timestamp
		) = @{$dep};
		my ( @route_pre, @route_post );

		if ( $stop and not( $stopname eq $stop ) ) {
			next;
		}

		if ( not $timestamp ) {
			cluck("departure element without timestamp: $dep");
			next;
		}

		$timestamp /= 1000;

		if ( $hide_past and $ts_now > $timestamp ) {
			next;
		}

		my $dt_dep = DateTime->from_epoch(
			epoch     => $timestamp,
			time_zone => 'Europe/Berlin'
		);
		my $ts_dep = $dt_dep->epoch;

		if ($full_routes) {
			my @route = map { [ $_->[9] / 1000, $_->[1] ] }
			  grep { $_->[8] == $tripid } @{ $self->{raw_list} };

			@route_pre  = grep { $_->[0] < $ts_dep } @route;
			@route_post = grep { $_->[0] > $ts_dep } @route;

			if ( $via
				and none { $_->[1] eq $via } @route_post )
			{
				next;
			}

			if ($hide_past) {
				@route_pre = grep { $_->[0] >= $ts_now } @route_pre;
			}

			@route_pre = map { $_->[0] }
			  sort { $a->[1] <=> $b->[1] }
			  map { [ $_, $_->[0] ] } @route_pre;
			@route_post = map { $_->[0] }
			  sort { $a->[1] <=> $b->[1] }
			  map { [ $_, $_->[0] ] } @route_post;

			@route_pre = map {
				Travel::Status::DE::URA::Stop->new(
					datetime => DateTime->from_epoch(
						epoch     => $_->[0],
						time_zone => 'Europe/Berlin'
					),
					name => decode( 'UTF-8', $_->[1] )
				  )
			} @route_pre;
			@route_post = map {
				Travel::Status::DE::URA::Stop->new(
					datetime => DateTime->from_epoch(
						epoch     => $_->[0],
						time_zone => 'Europe/Berlin'
					),
					name => decode( 'UTF-8', $_->[1] )
				  )
			} @route_post;
		}

		push(
			@results,
			Travel::Status::DE::URA::Result->new(
				datetime    => $dt_dep,
				dt_now      => $dt_now,
				line        => $linename,
				line_id     => $lineid,
				destination => decode( 'UTF-8', $dest ),
				route_pre   => [@route_pre],
				route_post  => [@route_post],
				stop        => $stopname,
				stop_id     => $stopid,
			)
		);
	}

	@results = map { $_->[0] }
	  sort { $a->[1] <=> $b->[1] }
	  map { [ $_, $_->datetime->epoch ] } @results;

	$self->{results} = \@results;

	return @results;
}

1;

__END__

=head1 NAME

Travel::Status::DE::URA - unofficial departure monitor for "Unified Realtime
API" data providers (e.g. ASEAG)

=head1 SYNOPSIS

    use Travel::Status::DE::URA;

    my $status = Travel::Status::DE::URA->new(
        ura_base => 'http://ivu.aseag.de/interfaces/ura',
        ura_version => '1',
        stop => 'Aachen Bushof'
    );

    for my $d ($status->results) {
        printf(
            "%s  %-5s %25s (in %d min)\n",
            $d->time, $d->line, $d->destination, $d->countdown
        );
    }

=head1 VERSION

version 0.04

=head1 DESCRIPTION

Travel::Status::DE::URA is an unofficial interface to URA-based realtime
departure monitors (as used e.g. by the ASEAG).  It reports all upcoming
departures at a given place in real-time.  Schedule information is not
included.

=head1 METHODS

=over

=item my $status = Travel::Status::DE::URA->new(I<%opt>)

Requests the departures as specified by I<opts> and returns a new
Travel::Status::DE::URA object.

The following two parameters are mandatory:

=over

=item B<ura_base> => I<ura_base>

The URA base url.

=item B<ura_version> => I<version>

The version, may be any string.

=back

The request URL is I<ura_base>/instant_VI<version>, so for
C<< http://ivu.aseag.de/interfaces/ura >>, C<< 1 >> this module will send
requests to C<< http://ivu.aseag.de/interfaces/ura/instant_V1 >>.

The following parameter is optional:

=over

=item B<lwp_options> => I<\%hashref>

Passed on to C<< LWP::UserAgent->new >>. Defaults to C<< { timeout => 10 } >>,
you can use an empty hashref to override it.

=back

Additionally, all options supported by C<< $status->results >> may be specified
here, causing them to be used as defaults. Note that while they can be
overridden later, they may limit the set of departures requested from the
server.

=item $status->errstr

In case of an HTTP request error, returns a string describing it. If none
occured, returns undef.

=item $status->get_stop_by_name(I<$stopname>)

Returns a list of stops matching I<$stopname>. For instance, if the stops
"Aachen Bushof", "Eupen Bushof", "Brand" and "Brandweiher" exist, the
parameter "bushof" will return "Aachen Bushof" and "Eupen Bushof", while
"brand" will only return "Brand".

=item $status->results(I<%opt>)

Returns a list of Travel::Status::DE::URA::Result(3pm) objects, each describing
one departure.

Accepted parameters (all are optional):

=over

=item B<calculate_routes> => I<bool> (default 0)

When set to a true value: Compute routes for all results, enabling use of
their B<route_> accessors. Otherwise, those will just return nothing
(undef / empty list, depending on context).

=item B<hide_past> => I<bool> (default 1)

Do not include past departures in the result list and the computed timetables.

=item B<stop> => I<name>

Only return departures at stop I<name>.

=item B<via> => I<vianame>

Only return departures containing I<vianame> in their route after their
corresponding stop. Implies B<calculate_routes>=1.

=back

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * DateTime(3pm)

=item * List::MoreUtils(3pm)

=item * LWP::UserAgent(3pm)

=item * Text::CSV(3pm)

=back

=head1 BUGS AND LIMITATIONS

Many.

=head1 SEE ALSO

Travel::Status::DE::URA::Result(3pm).

=head1 AUTHOR

Copyright (C) 2013-2015 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
