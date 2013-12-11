package Travel::Status::DE::ASEAG;

use strict;
use warnings;
use 5.010;

no if $] >= 5.018, warnings => "experimental::smartmatch";

our $VERSION = '0.00';

use Carp qw(confess cluck);
use DateTime;
use Encode qw(encode decode);
use Travel::Status::DE::ASEAG::Result;
use LWP::UserAgent;

sub new {
	my ( $class, %opt ) = @_;

	my $ua = LWP::UserAgent->new(%opt);

	my $self = {
		full_routes => $opt{full_routes} // 0,
		fuzzy       => $opt{fuzzy}       // 1,
		stop        => $opt{stop},
		post        => {
			ReturnList =>
			  'lineid,linename,directionid,destinationtext,vehicleid,'
			  . 'tripid,estimatedtime,stopid,stoppointname'
		},
	};

	bless( $self, $class );

	$ua->env_proxy;

	my $response = $ua->post( 'http://ivu.aseag.de/interfaces/ura/instant_V1',
		$self->{post} );

	if ( $response->is_error ) {
		$self->{errstr} = $response->status_line;
		return $self;
	}

	$self->{raw_str} = $response->decoded_content;

	for my $dep ( split( /\r\n/, $self->{raw_str} ) ) {
		$dep =~ s{^\[}{};
		$dep =~ s{\]$}{};

		# first field == 4 => version information, no departure
		if ( substr( $dep, 0, 1 ) != 4 ) {
			push( @{ $self->{raw_list} }, [ split( /"?,"?/, $dep ) ] );
		}
	}

	return $self;
}

sub new_from_raw {
	my ( $class, %opt ) = @_;

	my $self = { raw_str => $opt{raw_str}, };

	for my $dep ( split( /\r\n/, $self->{raw} ) ) {
		$dep =~ s{^\[}{};
		$dep =~ s{\]$}{};

		# first field == 4 => version information, no departure
		if ( substr( $dep, 0, 1 ) != 4 ) {
			push( @{ $self->{raw_list} }, [ split( /"?,"?/, $dep ) ] );
		}
	}

	return bless( $self, $class );
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub sprintf_date {
	my ($e) = @_;

	return sprintf( '%02d.%02d.%d',
		$e->getAttribute('day'),
		$e->getAttribute('month'),
		$e->getAttribute('year'),
	);
}

sub sprintf_time {
	my ($e) = @_;

	return sprintf( '%02d:%02d',
		$e->getAttribute('hour'),
		$e->getAttribute('minute'),
	);
}

sub is_my_stop {
	my ( $self, $stop, $my_stop, $fuzzy ) = @_;

	if ($fuzzy) {
		return ( $stop =~ m{ $my_stop }ix ? 1 : 0 );
	}
	else {
		return ( $stop eq $my_stop );
	}
}

sub results {
	my ( $self, %opt ) = @_;
	my @results;

	my $full_routes = $opt{full_routes} // $self->{full_routes} // 0;
	my $fuzzy       = $opt{fuzzy}       // $self->{fuzzy}       // 1;
	my $stop        = $opt{stop}        // $self->{stop};

	my $dt_now = DateTime->now( time_zone => 'Europe/Berlin' );

	for my $dep ( @{ $self->{raw_list} } ) {

		my (
			$u1, $stopname, $stopid,    $lineid, $linename,
			$u2, $dest,     $vehicleid, $tripid, $timestamp
		) = @{$dep};
		my @route;

		if ( $stop and not $self->is_my_stop( $stopname, $stop, $fuzzy ) ) {
			next;
		}

		if ( not $timestamp ) {
			cluck("departure element without timestamp: $dep");
			next;
		}

		if ($full_routes) {
			@route = map { [ $_->[9] / 1000, $_->[1] ] }
			  grep { $_->[8] == $tripid } @{ $self->{raw_list} };

			@route = map { $_->[0] }
			  sort { $a->[1] <=> $b->[1] }
			  map { [ $_, $_->[0] ] } @route;

			@route = map {
				[
					DateTime->from_epoch(
						epoch     => $_->[0],
						time_zone => 'Europe/Berlin'
					  )->hms,
					decode( 'UTF-8', $_->[1] )
				]
			} @route;
		}

		my $dt_dep = DateTime->from_epoch(
			epoch     => $timestamp / 1000,
			time_zone => 'Europe/Berlin'
		);

		push(
			@results,
			Travel::Status::DE::ASEAG::Result->new(
				date        => $dt_dep->strftime('%d.%m.%Y'),
				time        => $dt_dep->strftime('%H:%M:%S'),
				datetime    => $dt_dep,
				line        => $linename,
				line_id     => $lineid,
				destination => decode( 'UTF-8', $dest ),
				countdown =>
				  $dt_dep->subtract_datetime($dt_now)->in_units('minutes'),
				countdown_sec =>
				  $dt_dep->subtract_datetime($dt_now)->in_units('seconds'),
				route_timetable => [@route],
			)
		);
	}

	@results = map { $_->[0] }
	  sort { $a->[1] <=> $b->[1] }
	  map { [ $_, $_->countdown ] } @results;

	$self->{results} = \@results;

	return @results;
}

1;

__END__

=head1 NAME

Travel::Status::DE::ASEAG - unofficial ASEAG departure monitor

=head1 SYNOPSIS

    use Travel::Status::DE::ASEAG;

    my $status = Travel::Status::DE::ASEAG->new(
        stop => 'Aachen Bushof'
    );

    for my $d ($status->results) {
        printf(
            "%s  %-5s %25s (in %d min)\n",
            $d->time, $d->line, $d->destination, $d->countdown
        );
    }

=head1 VERSION

version 1.04

=head1 DESCRIPTION

Travel::Status::DE::ASEAG is an unofficial interface to an ASEAG departure
monitor. It reports all upcoming departures at a given place in real-time.
Schedule information is not included.

=head1 METHODS

=over

=item my $status = Travel::Status::DE::ASEAG->new(I<%opt>)

Requests the departures as specified by I<opts> and returns a new
Travel::Status::DE::ASEAG object.  Dies if the wrong I<opts> were passed.

Arguments:

=over

=item B<stop> => I<name>

Name of the stop to list departures for.

=item B<fuzzy> => I<bool>

A true value (default) allows fuzzy matching for the I<name> set above,
a false one requires an exact string match.

=back

=item $status->errstr

In case of an HTTP request error, returns a string describing it. If none
occured, returns undef.

=item $status->results

Returns a list of Travel::Status::DE::ASEAG::Result(3pm) objects, each describing
one departure.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * DateTime(3pm)

=item * LWP::UserAgent(3pm)

=back

=head1 BUGS AND LIMITATIONS

Many.

=head1 SEE ALSO

aseag-m(1), Travel::Status::DE::ASEAG::Result(3pm).

=head1 AUTHOR

Copyright (C) 2013 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
