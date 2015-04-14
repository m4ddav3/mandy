#!/usr/bin/env perl
use strict; use warnings;

use Data::Dumper;
use GD;
#use bignum;

my $scale = (1/51200);
my ($y_size, $x_size) = (900, 1600);
#my ($y_size, $x_size) = (60, 90);
#my ($y_size, $x_size) = (90, 160);
#my ($x_origin, $y_origin) = (-1.75005, -0.011802);
#my ($x_origin, $y_origin) = (-1.75004622, -0.011802019);
my ($x_origin, $y_origin) = (-0.7453,0.1127);

my $max_iters   = 16777215;
my $max_colours = 16777215; # 255 (b), 65536 (gb), or 16777215 (rgb)

my $limit     = 4;

my $output_filename = sprintf('mandy-%d.png', time);

my $pixels = [[]];
my $low_pixel  = $max_iters;
my $high_pixel = 0;

sub val_to_rgb {
    my ($val) = @_;

    my $b = $val & 0xff;
    $val = $val >> 8;
    my $g = $val & 0xff;
    $val = $val >> 8;
    my $r = $val & 0xff;

    print sprintf("%s -> (%3s, %3s, %3s)\n", $_[0], $r, $g, $b);

    return ($r, $g, $b);
}

sub scale_int {
    my ($val, $in_min, $in_max, $out_min, $out_max) = @_;

    return int(($val - $in_min) * ($out_max - $out_min)
           / ($in_max - $in_min) + $out_min + 0.5);
}

print sprintf("Scale is: %s\n", $scale);

my $min_x = ($x_origin / $scale) - int($x_size / 2);
my $min_y = ($y_origin / $scale) - int($y_size / 2);

my $max_x = ($x_origin / $scale) + int($x_size / 2);
my $max_y = ($y_origin / $scale) + int($y_size / 2);

print sprintf("top left is (%s,%s), bottom right is (%s,%s)\n", $min_x, $min_y, $max_x, $max_y);

my $min_calc_x = $min_x * $scale;
my $max_calc_x = $max_x * $scale;

my $min_calc_y = $min_y * $scale;
my $max_calc_y = $max_y * $scale;

print sprintf("X: %s to %s = %s to %s\n", 0, $x_size, ($min_x + 0) * $scale, ($min_x + $x_size) * $scale);
print sprintf("Y: %s to %s = %s to %s\n", 0, $y_size, ($min_y + 0) * $scale, ($min_y + $y_size) * $scale);

#exit;
my $image = GD::Image->new($x_size, $y_size, 1);

my $colours = {
    0        => $image->colorAllocate(  0,  0,  0),
    16777215 => $image->colorAllocate(255,255,255),
};

my ($x1, $x2, $y1, $y2) = (0, 0, 0, 0);
my $iters = 0;

my ($x_pos, $y_pos) = (0, 0);

# This draws lines in an interlaced fashion, used when I want to see the
# rough target area
my @yvals = ();
#if (0) {
    my $vals = {};
    map $vals->{$_}++, (0..$y_size);

    #foreach my $v (64,32,16,8,4,2) {
    foreach my $v (8,4,2) {
        my @grepped = sort { $a <=> $b } grep { $_ % $v == 1 } keys %$vals;
        print sprintf("%s: %s\n", $v, join(', ', @grepped));
        map { delete $vals->{$_} } @grepped;

        push @yvals,  @grepped;
    }

    push @yvals, sort { $a <=> $b } keys %$vals;
#}

my $seen = {};
my $last_time = time;
for my $y (@yvals) {
#for my $y (0..$y_size) {
    for my $x (0..$x_size) {
        $x_pos = ($min_x + $x) * $scale;
        $y_pos = ($min_y + $y) * $scale;

        ($x1, $y1) = ($x_pos, $y_pos);

        $iters = 0;
        while ($iters <= $max_iters) {
            $iters++;

            $x2 = ($x1 ** 2) - ($y1 ** 2) + $x_pos;
            $y2 = (2 * $x1 * $y1) + $y_pos;

            ($x1, $y1) = ($x2, $y2);

            # Divergence test
            last if ($limit < (($x1 ** 2) + ($y1 ** 2)));
        }

        if ($iters > $max_iters) {
            # Convergence is black (palette entry #0)
            $image->setPixel($x, $y, 0);
            $pixels->[$x]->[$y] = 0;
        }
        else {
            $pixels->[$x]->[$y] = $iters;
            if ($iters < $low_pixel) {
                $low_pixel = $iters;
            }
            elsif ($iters > $high_pixel) {
                $high_pixel = $iters;
            }

            #my ($r, $g, $b) = val_to_rgb(scale_int($iters, 0, $max_iters, 0, 16777215));
            #if ($max_iters > 16777215) {
                $iters = scale_int($iters, 0, $max_iters, 0, $max_colours);
            #}
            #$colours->{$iters} //= $image->colorAllocate(val_to_rgb(scale_int($iters, 0, $max_iters, 0, 16777215)));
            $colours->{$iters} //= $image->colorAllocate(val_to_rgb($iters));
            $image->setPixel($x, $y, $colours->{$iters});

        }

        if (time - $last_time > 60) {
            $last_time = time;
            open (my $fh, '>', $output_filename);
            binmode($fh);
            print $fh $image->png;
            close $fh;
        }
    }
}

my $white = $colours->{16777215};
my $x_center = int($x_size/2);
my $y_center = int($y_size/2);

for my $p (-10..10) {
    $image->setPixel($x_center + $p, $y_center, $white);
    $image->setPixel($x_center, $y_center + $p, $white);
}

print Dumper $colours;
{
    open (my $fh, '>', $output_filename);
    binmode($fh);
    print $fh $image->png;
    close $fh;
}

my $image2 = GD::Image->new($x_size, $y_size, 1);
$colours = {};

for my $x (0..$x_size) {
    for my $y (0..$y_size) {
        my $v = $pixels->[$x]->[$y];
        $colours->{$v} //= $image2->colorAllocate(val_to_rgb(scale_int($v, $low_pixel, $max_colours, 0, $max_colours)));
        $image2->setPixel($x, $y, $colours->{$v});
    }
}

$output_filename =~ s{(\.png)}{-2$1};
open (my $fh, '>', $output_filename);
binmode($fh);
print $fh $image2->png;
close $fh;
