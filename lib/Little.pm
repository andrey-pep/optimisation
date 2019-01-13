package Little;

use strict;
use warnings;
use utf8;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(new calc);
use Constants;
use Data::Dumper;
use Node;

sub nodes { return $_[0]->{_nodes} }
sub main_matrix { return $_[0]->{_main_matrix} }

sub new {
	my ($class, %p) = @_;

	return bless{
		_main_matrix 	=>	$p{main_matrix},
		_nodes			=>	[],
	}, $class;
}

sub push_nodes {
	my ($self, @nodes) = @_;

	for my $node (@nodes) {
		push @{$self->{_nodes}}, $node; 
	}
}

sub calc {
	my ($self) = @_;

	my $result;

	my $work_matrix = $self->main_matrix->copy_matrix;
	my $first_node = Node->new(matrix => $work_matrix);
	$self->push_nodes($first_node);

	while(1) {
		my $min_node;
		my $slice_num = 0;
		my $min_low_border = 18446744073709551615;
		for (my $i = 0; $i < scalar @{$self->nodes}; $i++) {				#проход по массиву сохранённых узлов
			if ($self->nodes->[$i]->low_border < $min_low_border) {		#для выбора узла с минимальной границей
				$min_node = $self->nodes->[$i];
				$min_low_border = $min_node->low_border;
				$slice_num = $i;
			}
		}

		#print "Working with matrix:\n";
		#$min_node->print;
		splice @{$self->nodes}, $slice_num, 1; #выкидываем узел из массива, т.к. начали над ним работу

		$min_node->substruct;

		my ($chosen_i, $chosen_j, $fine) = $min_node->choose_node();
										#Теперь наше множество S разбиваем на множества — содержащие ребро с максимальным штрафом(Sw) и не содержащие это ребро(Sw/o).
		my $new_node = Node->new((			#новое множество с исключенной ветвью Sw
				matrix 		=>	$min_node->copy_matrix_with_except($chosen_i, $chosen_j),
				path 		=> [[$min_node->matrix->[$chosen_i]->[0], $min_node->matrix->[0]->[$chosen_j]], @{$min_node->path}],
				low_border 	=>	$min_node->low_border,
			));

		$new_node->substruct;
		#print "fine: $fine i: $chosen_i j: $chosen_j\n";
		$min_node->{_low_border} += $fine;

		$self->push_nodes($new_node, $min_node);

		#print "result. new node:\n";
		#$new_node->print;
		#print "second (from min):\n";
		#$min_node->print;

		if (scalar @{$new_node->matrix} < 4) {
			#print "THE END MF\n";
			#$new_node->print;
			$result = $new_node;
			last;
		}

		if (scalar @{$min_node->matrix} < 4) {
			#print "THE END MF\n";
			#$min_node->print;
			$result = $min_node;
			last;
		}
	};

	return $result;
}

1;