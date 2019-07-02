package Travel::Status::DE::MM;

use strict;
use warnings;
use 5.010;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

our $VERSION = '2.01';

use parent 'Travel::Status::DE::URA';

sub new {
	my ( $class, %opt ) = @_;

	$opt{ura_base}    = 'http://ura.itcs.mvg-mainz.de/interfaces/ura';
	$opt{ura_version} = '1';

	return $class->SUPER::new(%opt);
}

1;

__END__

=head1 NAME

Travel::Status::DE::MM - unofficial Mainzer MobilitE<auml>t departure monitor.

=head1 SYNOPSIS

    use Travel::Status::DE::MM;

    my $status = Travel::Status::DE::MM->new(
        stop => 'Hauptbahnhof West'
    );

    for my $d ($status->results) {
        printf(
            "%s  %-5s %25s (in %d min)\n",
            $d->time, $d->line, $d->destination, $d->countdown
        );
    }

=head1 VERSION

version 2.01

=head1 DESCRIPTION

Travel::Status::DE::MM is an unofficial interface to the Mainzer
MobilitE<auml>t realtime departure monitor.

=head1 METHODS

=over

=item my $status = Travel::Status::DE::MM->new(I<%opt>)

Requests the departures as specified by I<opts> and returns a new
Travel::Status::DE::MM object.

Calls Travel::Status::DE::URA->new with the appropriate B<ura_base> and
B<ura_version> parameters. All I<opts> are passed on.

See Travel::Status::DE::URA(3pm) for the other methods.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Travel::Status::DE::URA(3pm)

=back

=head1 BUGS AND LIMITATIONS

Many.

=head1 SEE ALSO

MM-m(1), Travel::Status::DE::URA(3pm).

=head1 AUTHOR

Copyright (C) 2016, 2019 by Moritz Schlarb E<lt>moschlar@metalabs.deE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
