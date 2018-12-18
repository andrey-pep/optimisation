use warnings;
use strict;
use utf8;

use FindBin;
use lib $FindBin::Bin . '/lib';
use Node;
use Little;
use Constants;
use Data::Dumper;

my $default_matrix = [
	[0, 1, 2, 3, 4, 5, 6, 7],
	[1,INFINITY, 5, 9, 6, 3, 5, 9],
	[2, 8, INFINITY, 8, 8, 5, 9, 2],
	[3, 6, 9, INFINITY, 1, 6, 7, 3],
	[4, 7, 11, 4, INFINITY, 4, 2, 9],
	[5, 4, 6, 3, 2, INFINITY, 2, 8],
	[6, 5, 2, 2, 8, 4, INFINITY, 3],
	[7, 8, 1, 3, 16, 5, 3, INFINITY],
];

my $little_obj = create_new_task($default_matrix);
my $result = calc_with_params($little_obj);

printer($default_matrix);
print $result . "\n";

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

sub prepare_data {		#подготовка данных и запись в матрицу

}


sub printer {					#простой вывод матрицы без всего
	my ($matrix) = @_;

	my $l = scalar @{$matrix};

	for (my $i = 0; $i < $l; $i++) {
		print join(', ', @{$matrix->[$i]}) . "\n";
	}
}