package Constants;

use strict;
use warnings;
use utf8;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(INFINITY RESULT_WIDTH RESULT_HEIGTH POINT_SIZE INDENT);

use constant INFINITY => -1;

use constant RESULT_WIDTH => 500;
use constant RESULT_HEIGTH => 500;
use constant POINT_SIZE => 20;
use constant INDENT 	=> 20;