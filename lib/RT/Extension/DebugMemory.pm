use strict;
use warnings;
package RT::Extension::DebugMemory;

our $VERSION = '0.04';

=head1 NAME

RT-Extension-DebugMemory - Warns of memory growth

=head1 INSTALLATION

=over

=item perl Makefile.PL

=item make

=item make install

May need root permissions

=item Edit your F</opt/rt6/etc/RT_SiteConfig.pm>

Add this line:

    Plugin('RT::Extension::DebugMemory');

or add C<RT::Extension::DebugMemory> to your existing C<Plugin> line.

=item Restart your webserver

=back

=head1 USAGE

Requests which trigger changes in the RSS size of the process will be
logged at the WARN level, as follows:

    [warning]: MEM - 872[1]: (596K) | /
    [warning]: MEM - 872[1]: (4220K) > /
    [warning]: MEM - 872[2]: (160K) | /NoAuth/Login.html
    [warning]: MEM - 872[2]: (684K) > /NoAuth/Login.html
    [warning]: MEM - 872[3]: (2900K) > /
    [warning]: MEM - 872[4]: (4276K) > /Ticket/Display.html?id=1
    [warning]: MEM - 872[5]: (68K) > /Ticket/Display.html?id=1
    [warning]: MEM - 872[6]: (72K) > /Ticket/Display.html?id=1
    [warning]: MEM - 872[7]: (16K) > /Ticket/Display.html?id=1
                      ^  ^     ^   ^         ^
                      |  |     |   |         |
                     PID |     |   |         |
                         |     |   |         |
              Request number   |   |         |
                               |   |         |
                  RSS size change  |         |
                                   |         |
     ">" means post-cleanup of request       |
     "|" means during the request            |
                                     Request URI

The size of the process is monitored using the L<Proc::ProcessTable>
module to read the RSS (Resident Set Size) of the current process.

=head1 AUTHOR

Best Practical Solutions, LLC <modules@bestpractical.com>

=head1 BUGS

All bugs should be reported via
L<http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-DebugMemory>
or L<bug-RT-Extension-DebugMemory@rt.cpan.org>.


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2012-2025 by Best Practical Solutions, LLC

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

our $APP;
BEGIN {
    require RT::Interface::Web::Handler;
    $APP = RT::Interface::Web::Handler->PSGIApp;
}

use Plack::Builder;
no warnings 'redefine';

sub _get_rss {
    require Proc::ProcessTable;
    my $t = Proc::ProcessTable->new;
    for my $p (@{ $t->table }) {
        next unless $p->pid == $$;
        # On Darwin, Proc::ProcessTable returns RSS in KB; normalize to bytes
        return $^O eq 'darwin' ? $p->rss * 1024 : $p->rss;
    }
    return 0;
}

sub RT::Interface::Web::Handler::PSGIApp {
    my $i = 0;
    my $last;
    my $lastreq;
    builder {
        enable sub {
            my $app = shift;
            sub {
                my ($env) = @_;

                my $before = _get_rss();
                my $res    = $app->($env);
                my $after  = _get_rss();

                $i++;

                RT->Logger->debug("MEM DEBUG - $$\[$i]: before=$before after=$after last="
                    . (defined $last ? $last : 'undef')
                    . " delta=" . ($after - $before)
                    . " " . $env->{REQUEST_URI});

                if (defined $last and $before != $last) {
                    # Growth between the end of last request and start of
                    # this one is the fault of the previous request
                    my $rss = ( ($before - $last) / 1024) . "K";
                    RT->Logger->warning("MEM - $$\[$i]: ($rss) > $lastreq");
                }

                $last = $after;
                $lastreq = $env->{REQUEST_URI};

                return $res unless $after != $before;

                my $rss = ( ($after - $before) / 1024) . "K";
                RT->Logger->warning("MEM - $$\[$i]: ($rss) | ".$env->{REQUEST_URI});

                return $res;
            };
        };
        $APP;
    };
}

1;
