use Test::More tests => 5;
use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use List::Util qw(first);
use Slic3r;
use Slic3r::Test qw(_eq);
use Slic3r::Geometry qw(Z PI scale unscale);

my $config = Slic3r::Config->new_from_defaults;

my $test = sub {
    my ($conf) = @_;
    $conf ||= $config;
    
    my $print = Slic3r::Test::init_print('slopy_cube', config => $conf);
    
    my @z = ();
    my @increments = ();
    Slic3r::GCode::Reader->new->parse(Slic3r::Test::gcode($print), sub {
        my ($self, $cmd, $args, $info) = @_;
        
        if ($info->{dist_Z}) {
            push @z, 1*$args->{Z};
            push @increments, $info->{dist_Z};
        }
    });
    
    ok  (_eq($z[0], $config->get_value('first_layer_height') + $config->z_offset), 'first layer height.');
    
    ok  (_eq($z[1], $config->get_value('first_layer_height') + $config->get('max_layer_height')->[0] + $config->z_offset), 'second layer height.');
        
    cmp_ok((first { _eq($_, 10.0) } @z[1..$#z]), '>', 0, 'horizontal facet matched');
    
    1;
};




my $print = Slic3r::Test::init_print('slopy_cube', config => $config);
$print->models->[0]->mesh->repair();
my $adaptive_slicing = Slic3r::AdaptiveSlicing->new(
	mesh => Slic3r::Test::mesh('slopy_cube'),
	size => 20
);


subtest 'max cusp_height limited by extruder capabilities' => sub {
    plan tests => 3;

	is  ($adaptive_slicing->cusp_height(scale 1, 0.2, 0.1, 0.15), 0.15, 'low');
	is  ($adaptive_slicing->cusp_height(scale 1, 0.2, 0.1, 0.4), 0.4, 'higher');
	is  ($adaptive_slicing->cusp_height(scale 1, 0.2, 0.1, 0.65), 0.65, 'highest');
};
  
subtest 'min cusp_height limited by extruder capabilities' => sub {
    plan tests => 3;

	is  ($adaptive_slicing->cusp_height(scale 4, 0.01, 0.1, 0.15), 0.1, 'low');
	is  ($adaptive_slicing->cusp_height(scale 4, 0.02, 0.2, 0.4), 0.2, 'higher');
	is  ($adaptive_slicing->cusp_height(scale 4, 0.01, 0.3, 0.65), 0.3, 'highest');
};

subtest 'correct cusp_height depending on the facet normals' => sub {
    plan tests => 3;

	ok  (_eq($adaptive_slicing->cusp_height(scale 1, 0.1, 0.1, 0.5), 0.5), 'limit');
	ok  (_eq($adaptive_slicing->cusp_height(scale 4, 0.1, 0.1, 0.5), 0.1414), '45deg facet, cusp_value: 0.1');
	ok  (_eq($adaptive_slicing->cusp_height(scale 4, 0.15, 0.1, 0.5), 0.2121), '45deg facet, cusp_value: 0.15');
};


# 2.92893 ist lower slope edge
# distance to slope must be higher than min extruder cap.
# slopes cusp height must be greater than the distance to the slope
ok  (_eq($adaptive_slicing->cusp_height(scale 2.798, 0.1, 0.1, 0.5), 0.1414), 'reducing cusp_height due to higher slopy facet');

# slopes cusp height must be smaller than the distance to the slope
ok  (_eq($adaptive_slicing->cusp_height(scale 2.6289, 0.15, 0.1, 0.5), 0.3), 'reducing cusp_height to z-diff');

__END__