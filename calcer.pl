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
use GD::Image::AnimatedGif;
use Imager;
use Imager::File::GIF;
use Tk::Animation;
use Tk::ROText;

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
$mw->geometry("800x600");
$mw->title("Optimisation");
my $shot;
my $clear_image;
my $result_win;

my $main_frame = $mw->Frame()->pack(-side => 'top', -fill => 'x'); 
my $top_frame = $main_frame->Frame(-background => "white")->pack(-side => 'top',
                                                                   -fill => 'x');
my $bottom_frame = $main_frame->Frame(-background => "white")->pack(-side => "bottom", -fill => 'y');
my $left_frame = $main_frame->Frame(-background => "white")->pack(-side => 'left',  -fill => 'y');
my $right_frame = $main_frame->Frame(-background => "white")->pack(-side => "right");

$top_frame->Label(-text => "Оптимизация процесса сверления", 
                                   -background => "white")->pack(-side => "top");

my $copy_entry_x;
my $copy_entry_y;
my $copy_button;

my $clear_text = $right_frame->Button(-text => "Clear Text", 
                          -command => \&clear_entry)->pack(-side => "top");
my $paste_text = $right_frame->ROText(-background => "white", 
                            -foreground => "black")->pack(-side => "top");

my $menu = $left_frame->Menubutton(-text => 'Способ введения координат', -tearoff => 'false')->pack(-side => 'top');

$menu->command(-label => 'Открыть файл', -command => \&find_file);
$menu->command(-label => 'Ввести вручную', -command => \&input_by_self);

sub clear_entry {
  $paste_text->delete('0.0', 'end');
  splice @$points, 0, scalar @$points;
}
 
sub find_file {
	my $file = $main_frame->getOpenFile();
	my $yesno_button = $mw->messageBox(-message => "Использовать файл $file?",
                                        -type => "yesno", -icon => "question");
	$copy_entry_x->destroy() if $copy_entry_x;
	$copy_entry_y->destroy() if $copy_entry_y;
	$copy_button->destroy() if $copy_button;

	open(my $fh, "<", $file);
	if ($@) {
		$mw->messageBox(-message => "Проблема при открытии файла: $!", -type => "ok");
		return;
	}

	while(<$fh>) {
		chomp $_;
		my ($x, $y) = split(/\t/, $_);
		unless ($x || $y) {
		  	$mw->messageBox(-message => "Для ввода данных используйте формат tsv", -type => "ok");
		  	return;
		}
		unless (looks_like_number($x) && looks_like_number($y) && $x >= 0 && $y >= 0) {
		  	$mw->messageBox(-message => "Введите положение отверстий в числовом формате (неотрицательные числа)!", -type => "ok");
		  	return;
		}

		if($max_value < $x) {
		  	$max_value = $x;
		}
		if($max_value < $y) {
			$max_value = $y;
		}

		$paste_text->insert("end", $x . ' : ' . $y . "\n");
		push @$points, {x => $x, y => $y};
	}
}

sub input_by_self {
	$copy_entry_x->destroy() if $copy_entry_x;
	$copy_entry_y->destroy() if $copy_entry_y;
	$copy_button->destroy() if $copy_button;

	$copy_entry_x = $left_frame->Entry(-background => "white", 
	                             -foreground => "black")->pack(-side => "left");
	$copy_entry_y = $left_frame->Entry(-background => "white", 
	                             -foreground => "black")->pack(-side => "left");
	$copy_button = $left_frame->Button(-text => "Добавить точку", 
	                           -command => \&copy_entry)->pack(-side => "right");
}

sub copy_entry {
  my $copied_x = $copy_entry_x->get();
  my $copied_y = $copy_entry_y->get();

  unless (looks_like_number($copied_x) && looks_like_number($copied_y) && $copied_x >= 0 && $copied_y >= 0) {
  	$mw->messageBox(-message => "Введите положение отверстий в числовом формате (неотрицательные числа)!", -type => "ok");
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

my $frame_handler = sub {
    my $frm = shift;
    my $imgx = GD::Image->new(shift) or die $!;
    $frm->copy($imgx,0,0,0,0,$frm->getBounds);
};

sub print_result_to_window {
	my ($answer) = @_;
	my $img = new GD::Image(RESULT_WIDTH,RESULT_HEIGTH);
	my $white = $img->colorAllocate(255,255,255);
	my $red = $img->colorAllocate(255,0,0);
	my $blue = $img->colorAllocate(0,0,255);
	my $black = $img->colorAllocate(0,0,0);

	open (my $result_fh, ">", FILE_RESULT_NAME) or $mw->messageBox(-message => "Не удалось создать файл результат: $!", -type => "ok");

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

	print $result_fh "1->\n";
	for my $branch(@$answer) {
		$img->arc(($points->[$branch->[0] - 1]->{x} + 1) * $scale, RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale,POINT_SIZE,POINT_SIZE,0,360,$blue);
		$img->fill(($points->[$branch->[0] - 1]->{x} + 1) * $scale - 5, RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale - 5, $blue);
		$etap++;
		print $result_fh $branch->[1] . "->\n";
	}

	$etap = 1;
	for my $branch (@$answer) {	
		if ($points->[$branch->[0] - 1]->{x} != $points->[$branch->[1] - 1]->{x}) {
			my $arrow = GD::Arrow::Full->new( 
				-X2		=>	($points->[$branch->[0] - 1]->{x} + 1) * $scale,
				-Y2 	=>	RESULT_HEIGTH -  ($points->[$branch->[0] - 1]->{y} + 1) * $scale,
				-X1 	=>	($points->[$branch->[1] - 1]->{x} + 1) * $scale,
				-Y1		=>	RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1)* $scale,
				-WIDTH 	=>	4,

			);	

			$img->polygon($arrow, $red);
			$img->filledPolygon($arrow, $red);
		}

		if ($points->[$branch->[1] - 1]->{y} != $points->[$branch->[0] - 1]->{y}) {
			my $arrow2 = GD::Arrow::Full->new( 
			    -X2    => ($points->[$branch->[1] - 1]->{x} + 1) * $scale, 
			    -Y2    => RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale, 
			    -X1    => ($points->[$branch->[1] - 1]->{x} + 1)* $scale, 
			    -Y1    => RESULT_HEIGTH - ($points->[$branch->[1] - 1]->{y} + 1) * $scale, 
			    -WIDTH => 4,
			);

			$img->polygon($arrow2, $red);
			$img->filledPolygon($arrow2, $red);
		}

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

	open(my $fh, ">", TMP_FILE_NAME . FORMAT);
	print $fh $img->png;
	close($fh);

	$etap = 1;

	my @for_gif_files;

	for my $branch (@$answer) {
		my $img2 = newFromPng GD::Image(TMP_FILE_NAME . FORMAT);
		if ($points->[$branch->[0] - 1]->{x} != $points->[$branch->[1] - 1]->{x}) {
			my $arrow = GD::Arrow::Full->new( 
				-X2		=>	($points->[$branch->[0] - 1]->{x} + 1) * $scale,
				-Y2 	=>	RESULT_HEIGTH -  ($points->[$branch->[0] - 1]->{y} + 1) * $scale,
				-X1 	=>	($points->[$branch->[1] - 1]->{x} + 1) * $scale,
				-Y1		=>	RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1)* $scale,
				-WIDTH 	=>	4,

			);	

			$img2->polygon($arrow, $blue);
			$img2->filledPolygon($arrow, $blue);
		}

		if ($points->[$branch->[1] - 1]->{y} != $points->[$branch->[0] - 1]->{y}) {
			my $arrow2 = GD::Arrow::Full->new( 
			    -X2    => ($points->[$branch->[1] - 1]->{x} + 1) * $scale, 
			    -Y2    => RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale, 
			    -X1    => ($points->[$branch->[1] - 1]->{x} + 1)* $scale, 
			    -Y1    => RESULT_HEIGTH - ($points->[$branch->[1] - 1]->{y} + 1) * $scale, 
			    -WIDTH => 4,
			);

			$img2->polygon($arrow2, $blue);
			$img2->filledPolygon($arrow2, $blue);
		}

		$img2->string(gdLargeFont, ($points->[$branch->[1] - 1]->{x} + 1) * $scale - 15, RESULT_HEIGTH - ($points->[$branch->[0] - 1]->{y} + 1) * $scale - 15, $etap, $blue);
		open(my $fh, ">", TMP_FILE_NAME . "$etap" . FORMAT);

		print $fh $img2->png;
		close($fh);
		push @for_gif_files, TMP_FILE_NAME . "$etap" . FORMAT;
		$etap++;
	}

	my $result_gif = Image::Magick->new();
	for my $file (@for_gif_files) {
		$result_gif->Read(filename=>"$file");
		unlink $file;
	}
	$result_gif->Write(filename => GIF_NAME, delay => DELAY);

	$result_win = $mw->Toplevel;
	$result_win->title("Результат");
	my $shot = $result_win->Animation(-format => 'gif', -file => GIF_NAME);
	my $resutl_frame = $result_win->Frame(-background => "white")->pack(-fill => 'y');
	$resutl_frame->Button(-image => $shot)->pack();
	$shot->start_animation(1000);
	my $result_text = $resutl_frame->ROText(-background => "white", 
                            -foreground => "black")->pack(-side => "top");
	$result_text->insert( "end", ($result_fh ? "Файл с результатом: " . FILE_RESULT_NAME . "\n" : "") . "Анимация результата: " . GIF_NAME);
	$clear_image = $bottom_frame->Button(-text => "Новый рассчет", 
                          -command => \&clear_image)->pack(-side => "bottom");
}

sub clear_image {
	clear_entry();
	push @$points, {x => 0, y => 0};
	$bottom_frame->update();
	$bottom_frame->destroy();
	$result_win->destroy;
	$bottom_frame = $main_frame->Frame(-background => "white")->pack(-side => "bottom", -fill => 'y');
	$max_value = 0;
}