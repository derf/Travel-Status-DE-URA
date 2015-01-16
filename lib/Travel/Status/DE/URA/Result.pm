package Travel::Status::DE::URA::Result;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

use DateTime::Format::Duration;

our $VERSION = '0.03';

Travel::Status::DE::URA::Result->mk_ro_accessors(
	qw(datetime destination line line_id stop stop_id));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}

sub countdown {
	my ($self) = @_;

	$self->{countdown} //= $self->datetime->subtract_datetime( $self->{dt_now} )
	  ->in_units('minutes');

	return $self->{countdown};
}

sub countdown_sec {
	my ($self) = @_;
	my $secpattern = DateTime::Format::Duration->new( pattern => '%s' );

	$self->{countdown_sec} //= $secpattern->format_duration(
		$self->datetime->subtract_datetime( $self->{dt_now} ) );

	return $self->{countdown_sec};
}

sub date {
	my ($self) = @_;

	return $self->datetime->strftime('%d.%m.%Y');
}

sub time {
	my ($self) = @_;

	return $self->datetime->strftime('%H:%M:%S');
}

sub type {
	return 'Bus';
}

sub route_timetable {
	my ($self) = @_;

	return @{ $self->{route_timetable} };
}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::URA::Result - Information about a single
departure received by Travel::Status::DE::URA

=head1 SYNOPSIS

    for my $departure ($status->results) {
        printf(
            "At %s: %s to %s (in %d minutes)",
            $departure->time, $departure->line, $departure->destination,
            $departure->countdown
        );
    }

=head1 VERSION

version 0.03

=head1 DESCRIPTION

Travel::Status::DE::URA::Result describes a single departure as obtained by
Travel::Status::DE::URA.  It contains information about the time,
line number and destination.

=head1 METHODS

=head2 ACCESSORS

=over

=item $departure->countdown

Time in minutes from the time Travel::Status::DE::URA was instantiated until
the bus will depart.

=item $departure->countdown_sec

Time in seconds from the time Travel::Status::DE::URA was instantiated until
the bus will depart.

=item $departure->date

Departure date (DD.MM.YYYY)

=item $departure->datetime

DateTime object holding the departure date and time.

=item $departure->destination

Destination name.

=item $departure->line

The name of the line.

=item $departure->line_id

The number of the line.

=item $departure->route_timetable

If the B<results> method of Travel::Status::DE::URA(3pm) was called with
B<full_routes> => true:
Returns a list of arrayrefs describing the entire route. I.e.
C<< ([$time1, $stop1], [$time2, $stop2], ...) >>.
The times are DateTime::Duration(3pm) objects, the stops are only names,
not IDs (subject to change).  Returns an empty list otherwise.

=item $departure->stop

The stop belonging to this departure.

=item $departure->stop_id

The stop ID belonging to this departure.

=item $departure->time

Departure time (HH:MM:SS).

=item $departure->type

Vehicle type for this departure. At the moment, this always returns "Bus".
This option exists for compatibility with other Travel::Status libraries.

=back

=head2 INTERNAL

=over

=item $departure = Travel::Status::DE::URA::Result->new(I<%data>)

Returns a new Travel::Status::DE::URA::Result object.  You should not need to
call this.

=item $departure->TO_JSON

Allows the object data to be serialized to JSON.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

Unknown.

=head1 SEE ALSO

Travel::Status::DE::URA(3pm).

=head1 AUTHOR

Copyright (C) 2013 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
