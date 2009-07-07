package App::Termcast;
use Moose;
use IO::Pty::Easy;
use IO::Socket::INET;
use Term::ReadKey;
with 'MooseX::Getopt';

=head1 NAME

App::Termcast -

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

has host => (
    is      => 'rw',
    isa     => 'Str',
    default => 'noway.ratry.ru',
);

has port => (
    is      => 'rw',
    isa     => 'Int',
    default => 31337,
);

has user => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { $ENV{USER} },
);

has password => (
    is      => 'rw',
    isa     => 'Str',
    default => 'asdf', # really unimportant
);

sub run {
    my $self = shift;
    my @argv = @{ $self->extra_argv };
    push @argv, ($ENV{SHELL} || '/bin/sh') if !@argv;

    my $socket = IO::Socket::INET->new(PeerAddr => $self->host,
                                       PeerPort => $self->port);
    $socket->write('hello '.$self->user.' '.$self->password."\n");

    my $pty = IO::Pty::Easy->new;
    $pty->spawn(@argv);
    my $termios = POSIX::Termios->new;
    $termios->getattr(fileno($pty->{pty}));
    my $lflag = $termios->getlflag;
    $termios->setlflag($lflag | POSIX::ECHO);
    $termios->setattr(fileno($pty->{pty}), POSIX::TCSANOW);

    my ($rin, $rout) = '';
    vec($rin, fileno(STDIN) ,1) = 1;
    vec($rin, fileno($pty->{pty}), 1) = 1;
    ReadMode 4;
    while (1) {
        my $ready = select($rout = $rin, undef, undef, undef);
        if (vec($rout, fileno(STDIN), 1)) {
            my $buf;
            sysread STDIN, $buf, 4096;
            if (!$buf) {
                warn "Error reading from stdin: $!" unless defined $buf;
                last;
            }
            $pty->write($buf);
        }
        if (vec($rout, fileno($pty->{pty}), 1)) {
            my $buf = $pty->read(0);
            if (!$buf) {
                warn "Error reading from pty: $!" unless defined $buf;
                last;
            }
            syswrite STDOUT, $buf;
            $socket->write($buf);
        }
    }
    ReadMode 0;
}

__PACKAGE__->meta->make_immutable;
no Moose;

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-app-termcast at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Termcast>.

=head1 SEE ALSO


=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc App::Termcast

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Termcast>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Termcast>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Termcast>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Termcast>

=back

=head1 AUTHOR

  Jesse Luehrs <doy at tozt dot net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Jesse Luehrs.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
