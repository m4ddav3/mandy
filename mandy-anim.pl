#!/usr/bin/env perl
use strict; use warnings;

use Data::Dumper;
use GD;

my $scale = (1/200);
my ($y_size, $x_size) = (768, 1024);
#my ($y_size, $x_size) = (200, 300);
my ($x_origin, $y_origin) = (-0.75, 0);
#my ($x_origin, $y_origin) = (-0.7453,0.1127);

my $max_iters = 255;#65535;#(65535) - 1;
my $limit     = 4;

sub val_to_rgb {
    my ($val) = @_;

    my $b = $val & 0xff;
    $val = $val >> 8;
    my $g = $val & 0xff;
    $val = $val >> 8;
    my $r = $val & 0xff;

    print sprintf("%s -> (%s, %s, %s)\n", $_[0], $r, $g, $b);

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

sub create_frame {
    my ($x_size, $y_size, $max_iters) = @_;

    print "Max Iterations: $max_iters\n";

    my $frame = GD::Image->new($x_size, $y_size);

    my $colours = {
        0 => $frame->colorAllocate(0,0,0),
    };

    map { $colours->{$_} = $frame->colorAllocate(0,0,$_) } (1..255);

    my ($x1, $x2, $y1, $y2) = (0, 0, 0, 0);
    my $iters = 0;

    my ($x_pos, $y_pos) = (0, 0);

    my $last_time = time;
    for my $y (0..$y_size) {
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
                $frame->setPixel($x, $y, 0);
            }
            else {
                #if ($max_iters > 16777215) {
                    $iters = scale_int($iters, 0, $max_iters, 0, 255);
                #}
                #$colours->{$iters} //= $frame->colorAllocate(val_to_rgb(scale_int($iters, 0, $max_iters, 0, 16777215)));
                $colours->{$iters} //= $frame->colorAllocate(val_to_rgb($iters));
                $frame->setPixel($x, $y, $colours->{$iters});
            }

        }
    }

    return $frame;
}

my $animation = GD::Image->new($x_size, $y_size);

for (0..255) {
    $animation->colorAllocate(0,0,$_);
}


open (my $fh, '>', 'mandy-anim-'.time.'.gif');
binmode($fh);

print $fh $animation->gifanimbegin;
print $fh $animation->gifanimadd;

for my $depth (1..128) {
    my $frame = create_frame($animation->getBounds, $depth*2);
    print $fh $frame->gifanimadd;

    open (my $framefh, '>', "frame-$depth.png");
    print $framefh $frame->png();
    close $framefh;
}

printf $fh $animation->gifanimend;
close $fh;
