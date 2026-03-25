#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Tiny;
use Encode qw(decode);
use Getopt::Long;

# ----------------------------------------------------------------------
# Fetch 96 quarter-hour values from two YLE Teksti-TV pages.
#
# Default sources:
#   https://yle.fi/tekstitv/txt/189_0003.htm
#   https://yle.fi/tekstitv/txt/189_0004.htm
#
# Each page is expected to contain 12 rows, and each accepted row must
# contain exactly 4 Finnish decimal-comma numbers, for example:
#   0,37 0,42 -1,05 2,18
#
# Output order is column-major within each page:
#   col1 rows 0..11, then col2 rows 0..11, then col3, then col4
#
# The script does NOT average values. It extracts and reorders raw values.
#
# Usage:
#   perl fetch_yle_prices.pl [--debug] [url1] [url2]
# ----------------------------------------------------------------------

our $DEBUG = 0;
GetOptions('debug!' => \$DEBUG);

sub dbg {
    return unless $DEBUG;
    warn "[DEBUG] $_[0]\n";
}

# Match Finnish decimal-comma numbers such as:
#   0,37
#   -12,45
#   +3,00
my $NUM_RE = qr/[+-]?\d{1,3},\d{2}/;

# ----------------------------------------------------------------------
# Fetch exactly 12 valid rows from a page.
#
# A valid row is any text line that contains exactly 4 numeric tokens
# matching $NUM_RE. The function scans the whole page line by line after
# stripping HTML tags.
#
# Returns:
#   Arrayref of 12 row arrayrefs, each row containing 4 numeric values
#   converted to Perl numbers with dot decimals.
# ----------------------------------------------------------------------
sub fetch_12_rows_anywhere {
    my ($http, $url) = @_;

    dbg("GET $url");
    my $res = $http->get($url);

    die "Fetch failed for $url: $res->{status} $res->{reason}\n"
        unless $res->{success};

    my $html = decode('UTF-8', $res->{content} // '');

    # Strip HTML to plain-ish text
    $html =~ s/<script\b.*?<\/script>//gis;
    $html =~ s/<style\b.*?<\/style>//gis;
    $html =~ s/<[^>]+>/ /g;
    $html =~ s/&nbsp;/ /g;
    $html =~ s/&amp;/&/g;

    my @rows;
    my $ln = 0;

    LINE: for my $line (split /\R/, $html) {
        ++$ln;

        my @nums = ($line =~ /$NUM_RE/g);

        dbg(sprintf "L%-4d tokens=%d %s",
            $ln, scalar(@nums), @nums ? join(' ', @nums) : '(none)');

        next LINE unless @nums == 4;

        my @row = map {
            (my $x = $_) =~ tr/,/./;
            0 + $x;
        } @nums;

        dbg(sprintf "  ACCEPT row %02d: [%.2f %.2f %.2f %.2f]",
            scalar(@rows), @row);

        push @rows, \@row;
        last LINE if @rows == 12;
    }

    die "Collected only " . scalar(@rows) . " rows from $url; expected 12\n"
        unless @rows == 12;

    return \@rows;
}

# ----------------------------------------------------------------------
# Flatten one page of 12x4 values into column-major order.
#
# Input:
#   [
#     [r0c0, r0c1, r0c2, r0c3],
#     [r1c0, r1c1, r1c2, r1c3],
#     ...
#     [r11c0, r11c1, r11c2, r11c3],
#   ]
#
# Output:
#   (c0r0..c0r11, c1r0..c1r11, c2r0..c2r11, c3r0..c3r11)
#
# Returns 48 raw values. No averaging is performed.
# ----------------------------------------------------------------------
sub page_col_major_values {
    my ($rows) = @_;

    my @cols = ([], [], [], []);

    for my $r (@$rows) {
        for my $i (0 .. 3) {
            push @{ $cols[$i] }, $r->[$i];
        }
    }

    my @out;
    for my $c (0 .. 3) {
        push @out, @{ $cols[$c] };
    }

    return @out;
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

my $url1 = shift(@ARGV) // 'https://yle.fi/tekstitv/txt/189_0003.htm';
my $url2 = shift(@ARGV) // 'https://yle.fi/tekstitv/txt/189_0004.htm';

my $http = HTTP::Tiny->new(
    timeout => 15,
    agent   => 'perl-yle-tekstitv-fetch/2.0',
);

my $rows1 = fetch_12_rows_anywhere($http, $url1);
my $rows2 = fetch_12_rows_anywhere($http, $url2);

my @vals1 = page_col_major_values($rows1);
my @vals2 = page_col_major_values($rows2);

if ($DEBUG) {
    dbg("Page 1: extracted " . scalar(@vals1) . " values in column-major order");
    dbg("Page 2: extracted " . scalar(@vals2) . " values in column-major order");
}

# Print all values, one per line:
#   first 48 from page 1, then 48 from page 2
printf "%.2f\n", $_ for (@vals1, @vals2);
