package Node;

use strict;
use warnings;
use utf8;	

use Constants;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(new substruct calc_g_coeff main_matrix low_border);

sub matrix { return $_[0]->{_matrix} }
sub low_border { return $_[0]->{_low_border} }
sub path { return $_[0]->{_path} }

sub new {
	my ($class, %p) = @_;

	return bless{
		_matrix 		=>	$p{matrix},
		_low_border		=>	$p{low_border} || 0,
		_path 			=>	$p{path} || [],
	}, $class;
}

sub print {
	my ($self) = shift;
	my $l = scalar @{$self->matrix};

	for (my $i = 0; $i < $l; $i++) {
		print join(', ', map { looks_like_number($_) ? sprintf("%3d", $_) : sprintf("%3s", $_) } @{$self->matrix->[$i]}) . "\n";
	}

	print "low border: " . $self->low_border . "\n";
	print "branches: " . join(",", map { sprintf("(%d, %d)", $_->[0], $_->[1] ) } @{$self->path}) . "\n";
}

sub substruct {
	my ($self) = @_;

	my $min_val;

	for (my $i = 1; $i < scalar @{$self->matrix}; $i++) {					#поиск минимального элемента строки
		for (my $j = 1; $j < scalar @{$self->matrix}; $j++) {
			next if ($self->matrix->[$i]->[$j] == INFINITY);
			unless(defined $min_val) {
				$min_val = $self->matrix->[$i]->[$j];
			}
			$min_val = $self->matrix->[$i]->[$j] if ($self->matrix->[$i]->[$j] < $min_val);
		}
		for (my $j = 1; $j < scalar @{$self->matrix}; $j++) {				#вычитание минимального элемента по строке
			next if ($self->matrix->[$i]->[$j] == INFINITY);
			$self->matrix->[$i]->[$j] -= $min_val;
		}
		$self->{_low_border} += $min_val;
		$min_val = undef;
	}

	for (my $i = 1; $i < scalar @{$self->matrix}; $i++) {
		for (my $j = 1; $j < scalar @{$self->matrix}; $j++) {				#поиск минимального элемента по столбцу
			next if ($self->matrix->[$j]->[$i] == INFINITY);
			unless(defined $min_val) {
				$min_val = $self->matrix->[$j]->[$i];
			}
			$min_val = $self->matrix->[$j]->[$i] if ($self->matrix->[$j]->[$i] < $min_val);
		}
		for (my $j = 1; $j < scalar @{$self->matrix}; $j++) {				#вычитание минимального элемента по столбцу
			next if ($self->matrix->[$j]->[$i] == INFINITY);
			$self->matrix->[$j]->[$i] -= $min_val;
		}
		$self->{_low_border} += $min_val;
		$min_val = undef;
	}

	return $self;
}

sub calc_g_coeff {						#получение штрафов
	my ($self, $r, $c) = @_;

	my $c_min = 18446744073709551615;
	my $r_min = 18446744073709551615;

	for (my $i = 1; $i < scalar @{$self->matrix}; $i++) {
		next if ($self->matrix->[$r]->[$i] == INFINITY);
		next if $i == $c;
		$r_min = $self->matrix->[$r]->[$i] if ($self->matrix->[$r]->[$i] < $r_min);
	}
	for (my $i = 1; $i < scalar @{$self->matrix}; $i++) {
		next if ($self->matrix->[$i]->[$c] == INFINITY);
		next if $i == $r;
		$c_min = $self->matrix->[$i]->[$c] if ($self->matrix->[$i]->[$c] < $c_min);
	}

	return $c_min + $r_min;
}

sub choose_node {		#выбор ветви с максимальным штрафом
	my ($self) = @_;

	my $chosen_i;
	my $chosen_j;
	my $max_koeff = 0;

	for (my $i = 1; $i < scalar @{$self->matrix}; $i++) {
		for (my $j = 1; $j < scalar @{$self->matrix}; $j++) {
			if ($self->matrix->[$i]->[$j] == 0) {
				my $tmp_koeff = $self->calc_g_coeff($i, $j);
				if ($tmp_koeff >= $max_koeff) {
					$chosen_j = $j;
					$chosen_i = $i;
					$max_koeff = $tmp_koeff;
				}
			}
		}
	}

	return $chosen_i, $chosen_j, $max_koeff;
}

sub copy_matrix {
	my ($self) = @_;

	my $l = scalar @{$self->matrix};
	my $new_matrix = [];

	for (my $i = 0; $i < $l; $i++) {
		for (my $j = 0; $j < $l; $j++) {
			$new_matrix->[$i]->[$j] = $self->matrix->[$i]->[$j];
		}
	}

	return $new_matrix;
}

sub copy_matrix_with_except {		#копирование матрицы с исключением строки/столбца и заменой необходимого элемента на бесконечность
	my ($self, $i_except, $j_except) = @_;

	my $new_matrix = [];
	my $k = 0;
	my $l = 0;
	my $i_new_except = 0;
	my $j_new_except = 0;

	for (my $i = 0, $k = 0; $i < scalar @{$self->matrix}; $i++) {
		next if $i == $i_except;
		for (my $j = 0, $l = 0; $j< scalar @{$self->matrix}; $j++) {
			next if $j == $j_except;
			$new_matrix->[$k]->[$l++] = $self->matrix->[$i]->[$j];
		}
		$k++;
	}

	my ($tmp_j, $tmp_i);
	my ($i_has_infinity, $j_has_ininity) = (0, 0);

	for (my $i = 1; $i < scalar @{$new_matrix}; $i++) {
		for (my $j = 1; $j< scalar @{$new_matrix}; $j++) {
			if ($new_matrix->[$i]->[$j] == INFINITY) {
				$i_has_infinity = 1;
				last;
			}
		}
		if ($i_has_infinity == 0) {
			$tmp_i = $i;
			last;
		}
		$i_has_infinity = 0;
	}

	for (my $i = 1; $i < scalar @{$new_matrix}; $i++) {
		for (my $j = 1; $j< scalar @{$new_matrix}; $j++) {
			if ($new_matrix->[$j]->[$i] == INFINITY) {
				$j_has_ininity = 1;
				last;
			}
		}
		if ($j_has_ininity == 0) {
			$tmp_j = $i;
			last;
		}
		$j_has_ininity = 0;
	}

	$new_matrix->[$tmp_i]->[$tmp_j] = INFINITY;

	return $new_matrix;
}

sub fix_infinity {
	my ($self, $x_str, $x_col) = @_;

	for my $tmp_node (@{$self->path}) {
		if ($x_str == $tmp_node->[0]) {

		}
	}
}