use strict;

use Module::Build;

my $build = Module::Build->new(
	module_name        => 'Gedcom::FOAF',
	dist_author        => 'Brian Cassidy <bricas@cpan.org>',
	license            => 'perl',
	create_readme      => 1,
	create_makefile_pl => 'traditional',
	requires           => {
		'XML::LibXML'      => 0
	},
	build_requires     => {
		'Test::More'  => 0,
		'File::Slurp' => 0
	},
);
$build->create_build_script;