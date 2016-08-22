#!perl
use strict;
use warnings;

use Time::HiRes qw( gettimeofday tv_interval sleep );
use constant refresh_period => 60;
use CPAN::Testers::TailLog;

my %seen;
my $fetcher = CPAN::Testers::TailLog->new();

while (1) {
    update();
    my $need_sleep = refresh_period;
    $need_sleep -= sleep($need_sleep) while $need_sleep > 0;

}

sub grade_color {
    $_[0] eq 'pass' and return "\e[1;32m";
    $_[0] eq 'fail' and return "\e[1;31m";
    return "\e[33m";
}

sub perl_version_color {

    # Stable RC's
    $_[0] =~ /perl-v5\.(24\.1|22\.3)\s*RC/
      and return "\e[30;41m";

    # Blead RLS
    $_[0] =~ /perl-v5\.25\.4/ and return "\e[30;45m";

    # Everything else
    return "\e[36m";
}

sub author_name {
    [ $_[0] =~ qr{\A([^/]+)/} ]->[0];
}

sub file_name {
    [ $_[0] =~ qr{\A[^/]+/(.*$)} ]->[0];
}

sub author_color {
    return '' unless $_[0] eq 'KENTNL';
    return "\e[30;42m" unless $_[1] ne 'pass';
    return "\e[30;43m";
}

sub update {
    my @new;
    my $new_items = 0;
    my $iter      = $fetcher->get_iter;
    while ( my $item = $iter->() ) {

        # stop iterating on re-match
        last if exists $seen{ $item->uuid };
        $new_items++;
        next if $item->grade eq 'pass' and $item->filename !~ m^KENTNL/^;

        # Vivify hash without wasting memory
        $seen{ $item->uuid } = undef;
        push @new, $item;
    }
    unless (@new) {
        printf "%s: \e[35m -- No Updates ($new_items new items) -- \e[0m\n",
          scalar localtime;
        return;
    }
    printf "\e[36m%s\e[0m:\n", scalar localtime;
    for my $item (@new) {
        my $grade = sprintf qq{%s%10s\e[0m}, grade_color( $item->grade ),
          $item->grade;

        my $author = author_name( $item->filename );
        my $filename = sprintf "%-55s", $item->filename;
        $filename =~ s{
            \A\Q$author\E
        }{
            author_color($author, $item->grade) . $author . "\e[0m"
        }ex;

        my $perl = sprintf "%s%-20s\e[0m",
          perl_version_color( $item->perl_version ), $item->perl_version;
        printf "%s: %s ( %s on \e[35m%-40s\e[0m => \e[34m%s\e[0m )\n",
          $grade, $filename, $perl, $item->platform, $item->uuid;
    }
}

