#!/usr/bin/perl
use warnings;
use strict;
use utf8;

use FindBin;
use lib $FindBin::Bin . '/lib';
use Node;
use Little;
use Constants;
use Tk;
use Scalar::Util qw(looks_like_number);
use Data::Dumper;
use Image::Magick;
use Image::Magick::Q16;
use GD;
use GD::Arrow;
use Tk::PNG;

my $max_value = 0;

my $default_matrix = [];#[
#	[0, 1, 2, 3, 4, 5, 6, 7],
##	[1,INFINITY, 5, 9, 6, 3, 5, 9],
#	[2, 8, INFINITY, 8, 8, 5, 9, 2],
#	[3, 6, 9, INFINITY, 1, 6, 7, 3],
#	[4, 7, 11, 4, INFINITY, 4, 2, 9],
#	[5, 4, 6, 3, 2, INFINITY, 2, 8],
#	[6, 5, 2, 2, 8, 4, INFINITY, 3],
#	[7, 8, 1, 3, 16, 5, 3, INFINITY],
#];

my $points = [];
push @$points, {x => 0, y => 0};

my $mw = MainWindow->new;
$mw->geometry("700x600");
$mw->title("Optimisation");
 
my $main_frame = $mw->Frame()->pack(-side => 'top', -fill => 'x'); 
my $top_frame = $main_frame->Frame(-background => "red")->pack(-side => 'top',
                                                                   -fill => 'x');
my $left_frame = $main_frame->Frame(-background => "black")->pack(-side => 'left',                                                                   -fill => 'y');
my $right_frame = $main_frame->Frame(-background => "white")->pack(-side => "right");

$top_frame->Label(-text => "Оптимизация процесса сверления", 
                                   -background => "red")->pack(-side => "top");
$left_frame->Label(-text => "Введите координаты точки", -background => "black", 
                                    -foreground => "yellow")->pack(-side => "left");
my $copy_entry_x = $left_frame->Entry(-background => "white", 
                             -foreground => "red")->pack(-side => "left");
my $copy_entry_y = $left_frame->Entry(-background => "white", 
                             -foreground => "red")->pack(-side => "left");
my $copy_button = $left_frame->Button(-text => "Добавить точку", 
                           -command => \&copy_entry)->pack(-side => "right");
my $clear_text = $right_frame->Button(-text => "Clear Text", 
                          -command => \&clear_entry)->pack(-side => "top");
my $paste_text = $right_frame->Text(-background => "white", 
                            -foreground => "black")->pack(-side => "top");

sub clear_entry {
  $paste_text->delete('0.0', 'end');
}
 
sub copy_entry {
  my $copied_x = $copy_entry_x->get();
  my $copied_y = $copy_entry_y->get();

  unless (looks_like_number($copied_x) or looks_like_number($copied_y)) {
  	$mw->messageBox(-message => "Введите положение отверстий в числовом формате!", -type => "ok");
  	return;
  }

  $paste_text->insert("end", $copied_x . ' : ' . $copied_y . "\n");
  $copy_entry_x->delete('0.0', 'end');
  $copy_entry_y->delete('0.0', 'end');

  if($max_value < $copied_x) {
  	$max_value = $copied_x;
  }

  if($max_value < $copied_y) {
  	$max_value = $copied_y;
  }

  push @$points, {x => $copied_x, y => $copied_y};
}


$mw->Label(-text => 'Optimisation')->pack();
 
$mw->Button(-text => "Решить", -command => \&start_colculations)->pack();
 
$mw->MainLoop;

sub start_colculations {
	if (scalar @$points < 2) {
		$mw->messageBox(-message => "Добавьте как минимум 2 точки!", -type => "ok");
		return;
	}
	prepare_data();
	my $little_obj = create_new_task($default_matrix);
	my $result = calc_with_params($little_obj);
	my $answer = find_answer_in_result($result);

	print_result_to_window($answer);
	#warn Dumper($result);
}

sub create_new_task {				#создание новой задачи
	my ($matrix) = @_;

	my $root_matrix = Node->new(matrix => $matrix);
	my $root_copy = Node->new(matrix => $root_matrix->copy_matrix);

	my $little_obj = Little->new(main_matrix => $root_copy);

	return $little_obj;
}

sub calc_with_params {			#вызов решателя
	my ($little_obj) = @_;

	$little_obj->calc();
}

sub output_to_window {		#вывод матрицы/результата в окно

}

sub find_answer_in_result {
	my ($result) = @_;

	my @all_the_path = (@{$result->path});
$result->print;
	if ($result->matrix->[1]->[1] != INFINITY) {
		push @all_the_path, [$result->matrix->[0]->[1], $result->matrix->[1]->[0]];
		push @all_the_path, [$result->matrix->[0]->[2], $result->matrix->[2]->[0]];
	} else {
		push @all_the_path, [$result->matrix->[2]->[0], $result->matrix->[0]->[1]];
		push @all_the_path, [$result->matrix->[1]->[0], $result->matrix->[0]->[2]];
	} 

	my @sorted_path = ();
	my $next_position = 1;
	for (my $i = 0; $i < scalar @$points; $i++) {
		for (my $j = 0; $j < scalar @$points; $j++) {
			my $branch = $all_the_path[$j];
			if ($branch->[0] == $next_position) {
				$sorted_path[$i] = [$branch->[0], $branch->[1]];
				$next_position = $branch->[1];
				splice @all_the_path, $j, 1;
				last;
			} elsif($branch->[1] == $next_position) {
				$sorted_path[$i] = [$branch->[1], $branch->[0]];
				$next_position = $branch->[0];
				splice @all_the_path, $j, 1;
				last;
			}
		}
	}

	return \@sorted_path;
}

sub prepare_data {		#подготовка данных и запись в матрицу
	for (my $i = 1; $i < scalar @$points + 1; $i++) {
		for (my $j = $i; $j < scalar @$points + 1; $j++) {
			if ($i == $j) {
				$default_matrix->[$i]->[$j] = INFINITY;
			} else {
				my $distance = abs($points->[$i - 1]->{x} - $points->[$j - 1]->{x}) + abs($points->[$i - 1]->{y} - $points->[$j - 1]->{y});
				$default_matrix->[$i]->[$j] = $distance;
				$default_matrix->[$j]->[$i] = $distance;
			}
		}
	}
	for (my $i = 0; $i < scalar @$points + 1; $i++) {
		$default_matrix->[0]->[$i] = "$i";
		$default_matrix->[$i]->[0] = "$i";
	}
}


sub printer {					#простой вывод матрицы без всего
	my ($matrix) = @_;

	my $l = scalar @{$matrix};

	for (my $i = 0; $i < $l; $i++) {
		print join(', ', @{$matrix->[$i]}) . "\n";
	}
}

sub print_result_to_window {
	my ($answer) = @_;
	my $img = new GD::Image(RESULT_WIDTH,RESULT_HEIGTH);
	my $white = $img->colorAllocate(255,255,255);
	my $red = $img->colorAllocate(255,0,0);
	my $blue = $img->colorAllocate(0,0,255);
	my $black = $img->colorAllocate(0,0,0);

	my $scale = (RESULT_WIDTH - POINT_SIZE) / ($max_value + 1);

	my $etap = 1;

	my $x_line = GD::Arrow::Full->new( 
	    -X2    => $scale, 
	    -Y2    => RESULT_HEIGTH - $scale, 
	    -X1    => RESULT_WIDTH, 
	    -Y1    => RESULT_HEIGTH - $scale, 
	    -WIDTH => 2,
	);
	$img->filledPolygon($x_line, $blue);
	$img->polygon($x_line, $blue);

	my $y_line = GD::Arrow::Full->new( 
	    -X2    => $scale, 
	    -Y2    => RESULT_HEIGTH - $scale, 
	    -X1    => $scale, 
	    -Y1    => 0, 
	    -WIDTH => 2,
	);
	$img->filledPolygon($y_line, $blue);
	$img->polygon($y_line, $blue);

	for my $branch(@$answer) {
		$img->arc(($points->[$branch->[0] - 1]->{x} + 1) * $scale, RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale,POINT_SIZE,POINT_SIZE,0,360,$blue);
		$img->fill(($points->[$branch->[0] - 1]->{x} + 1) * $scale - 5, RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale - 5, $blue);
		$etap++;
	}
	$etap = 1;
	for my $branch (@$answer) {
		#warn Dumper($points->[$branch->[0] - 1]->{x} * $scale);
		#warn Dumper($points->[$branch->[0] - 1]->{y} * $scale);	

		my $arrow = GD::Arrow::Full->new( 
			-X2		=>	($points->[$branch->[0] - 1]->{x} + 1) * $scale,
			-Y2 	=>	RESULT_HEIGTH -  ($points->[$branch->[0] - 1]->{y} + 1) * $scale,
			-X1 	=>	($points->[$branch->[1] - 1]->{x} + 1) * $scale,
			-Y1		=>	RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1)* $scale,
			-WIDTH 	=>	4,

		);	

		$img->polygon($arrow, $red);
		$img->filledPolygon($arrow, $red);

		my $arrow2 = GD::Arrow::Full->new( 
		    -X2    => ($points->[$branch->[1] - 1]->{x} + 1) * $scale, 
		    -Y2    => RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale, 
		    -X1    => ($points->[$branch->[1] - 1]->{x} + 1)* $scale, 
		    -Y1    => RESULT_HEIGTH - ($points->[$branch->[1] - 1]->{y} + 1) * $scale, 
		    -WIDTH => 4,
		);

		$img->polygon($arrow2, $red);
		$img->filledPolygon($arrow2, $red);

		$img->string(gdLargeFont, ($points->[$branch->[1] - 1]->{x} + 1) * $scale - 15, RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale - 15, $etap, $blue);
		$etap++;
	}

	for (my $i = 0; $i <= $max_value + 1; $i++) {
		$img->line(0, RESULT_WIDTH - $i*$scale, 20, RESULT_HEIGTH - $i* $scale, $blue);
		$img->string(gdLargeFont, 10, RESULT_WIDTH - ($i - 10) * $scale, "X" . $i, $blue);
		$img->line($i*$scale, RESULT_HEIGTH, $i* $scale,RESULT_HEIGTH - 20, $blue) if $i != 0;
	}

	for (my $i = 0; $i <= $max_value + 1; $i++) {
		$img->dashedLine(0, RESULT_HEIGTH - $i*$scale, RESULT_WIDTH, RESULT_HEIGTH - $i* $scale, $blue);
		$img->dashedLine($i*$scale, RESULT_HEIGTH, $i* $scale,0, $blue) if $i != 0;
	}

	open(my $fh, ">", "tmp.png");
	print $fh $img->png;
	close($fh);
	my $shot = $mw->Photo(-format => 'png', -file => "tmp.png");
	$right_frame->Button(-text => 'Exit', -command => sub { exit },
            -image => $shot)->pack(-side => "top");
	$mw->MainLoop;
}