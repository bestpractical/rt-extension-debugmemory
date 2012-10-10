use strict;
use warnings;
package RT::Extension::DebugMemory;

our $VERSION = '0.03';

=head1 NAME

RT-Extension-DebugMemory - Warns of memory growth

=head1 INSTALLATION

=over

=item perl Makefile.PL

=item make

=item make install

May need root permissions

=item Edit your /opt/rt4/etc/RT_SiteConfig.pm

Add this line:

    Set(@Plugins, qw(RT::Extension::DebugMemory));

or add C<RT::Extension::DebugMemory> to your existing C<@Plugins> line.

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

The size of the process is monitored using the L<GTop> tool, namely the
L<GTop::ProcMem> package.

=head1 AUTHOR

Alex Vandiver <alexmv@bestpractical.com>

=head1 BUGS

All bugs should be reported via
L<http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-DebugMemory>
or L<bug-RT-Extension-DebugMemory@rt.cpan.org>.


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2012 by Best Practical Solutions, LLC

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

# GTop uses the loaded-ness of threads.pm to determine if it is in a
# multi-threaded environment.
if ( eval {require Apache2::MPM; Apache2::MPM->is_threaded} ) {
    require threads;
}

sub RT::Interface::Web::Handler::PSGIApp {
    my $i = 0;
    my $last;
    my $lastreq;
    builder {
        enable 'GTop::ProcMem', callback => sub {
            my ($env, $res, $before, $after) = @_;
            # $before, $after isa GTop::ProcMem

            if (defined $last and $before->rss != $last) {
                # Growth between the end of last request and start of
                # this one is the fault of the previous request
                my $rss = ( ($before->rss - $last) / 1024) . "K";
                RT->Logger->warning("MEM - $$\[$i]: ($rss) > $lastreq");
            }

            $i++;
            $last = $after->rss;
            $lastreq = $env->{REQUEST_URI};

            return unless $after->rss != $before->rss;

            my $rss = ( ($after->rss - $before->rss) / 1024) . "K";
            RT->Logger->warning("MEM - $$\[$i]: ($rss) | ".$env->{REQUEST_URI});
        };
        $APP;
    };
}

1;
