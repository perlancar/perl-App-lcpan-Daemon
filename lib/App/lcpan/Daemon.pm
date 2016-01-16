package App::lcpan::Daemon;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use App::lcpan ();

sub _init {
    my %args = @_;

    App::lcpan::_init(\%args, 'ro');

    # collect all the functions we want to expose into App::lcpan::Daemon
    # package.
    {
        require PERLANCAR::Module::List;
        no strict 'refs';

        $log->tracef("Enumerating functions ...");
        my $mods = PERLANCAR::Module::List::list_modules(
            "App::lcpan::Cmd::", {list_modules=>1});

        for my $mod (sort keys %$mods) {
            my $func = $mod; $func =~ s/.+:://;
            my $mod_pm = $mod; $mod_pm =~ s!::!/!g; $mod_pm .= ".pm";
            require $mod_pm;
            my $meta = ${"$mod\::SPEC"}{handle_cmd}
                or die "$mod does not contain \$SPEC{handle_cmd}";

            # we currently only support queries/ro-access to the DB (and
            # filesystem), so we exclude all functions that have the tags
            # 'write-to-db' or 'write-to-fs'.
            if (grep {/^write-to-fs/} @{ $meta->{tags} }) {
                $log->info("Skipped %s (has write-to-fs tag)", $mod);
                next;
            } elsif (grep {/^write-to-db/} @{ $meta->{tags} }) {
                $log->info("Skipped %s (has write-to-db tag)", $mod);
                next;
            }

            # remove connection args, we will connect once and provide the dbh
            # to the function via _init().
            my $args = $meta->{args};
            for (keys %App::lcpan::common_args) { delete $args->{$_} }

            # we also remove all arguments that have the 'expose-fs-path' tag
            # (can expose the full path of the server's filesystem).
            for (keys %$args) {
                delete $args->{$_}
                    if grep {/^expose-fs-path$/} @{ $args->{$_}{tags} // [] };
            }

            # install
            *{"App::lcpan::Daemon::$func"} = \&{"$mod\::handle_cmd"};
            ${"App::lcpan::Daemon::SPEC"}{$func} = $meta;
        }
    }
}

1;
# ABSTRACT: Daemon-mode lcpan

=head1 SYNOPSIS

See L<lcpand-simple> script for the L<Riap::Simple> server.

See C<www/lcpand.psgi> in this distribution's share files for the PSGI
application.


=head1 SEE ALSO

L<App::lcpan>

=cut
