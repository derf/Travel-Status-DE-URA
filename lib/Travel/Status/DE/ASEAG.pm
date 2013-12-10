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
		fuzzy => $opt{fuzzy} // 1,
		stop  => $opt{name},
		post  => {
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

	$self->{raw} = $response->decoded_content;

	return $self;
}

sub new_from_xml {
	my ( $class, %opt ) = @_;

	my $self = { raw => $opt{raw}, };

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
	my ( $self, $stop ) = @_;
	my $my_stop = $self->{stop};

	if ( $self->{fuzzy} ) {
		return ( $stop =~ m{ $my_stop }ix ? 1 : 0 );
	}
	else {
		return ( $stop eq $my_stop );
	}
}

sub results {
	my ($self) = @_;
	my @results;

	my $dt_now = DateTime->now( time_zone => 'Europe/Berlin' );

	for my $dep ( split( /\r\n/, $self->{raw} ) ) {
		$dep =~ s{^\[}{};
		$dep =~ s{\]$}{};

		my (
			$u1, $stopname, $stopid,    $lineid, $linename,
			$u2, $dest,     $vehicleid, $tripid, $timestamp
		) = split( /"?,"?/, $dep );

		# version information
		if ( $u1 == 4 ) {
			next;
		}

		if ( $self->{stop} and not $self->is_my_stop($stopname) ) {
			next;
		}

		if ( not $timestamp ) {
			cluck("departure element without timestamp: $dep");
			next;
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
        name => 'Aachen Bushof'
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
