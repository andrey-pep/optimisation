package Constants;

use strict;
use warnings;
use utf8;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(INFINITY RESULT_WIDTH RESULT_HEIGTH POINT_SIZE INDENT TMP_FILE_NAME FORMAT GIF_NAME DELAY FILE_RESULT_NAME FREQ);

use constant INFINITY => -1;

use constant RESULT_WIDTH => 500;
use constant RESULT_HEIGTH => 500;
use constant POINT_SIZE => 20;
use constant INDENT 	=> 20;
use constant TMP_FILE_NAME => "tmp";
use constant FORMAT => ".png";
use constant GIF_NAME => "animated.gif";
use constant DELAY => "100";
use constant FILE_RESULT_NAME => "result.txt";
use constant FREQ => 10;