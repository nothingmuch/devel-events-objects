#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME         => 'Devel::Events::Objects',
	VERSION_FROM => 'lib/Devel/Events/Objects.pm',
	INSTALLDIRS  => 'site',
	SIGN         => 1,
	PL_FILES     => { },
	PREREQ_PM    => {
		'Devel::Events'      => 0,
		'Tie::RefHash::Weak' => '0.06',
		'Variable::Magic'    => '0.04',
		'Task::Weaken'       => 0,
		'Test::use::ok'      => 0,
	},
);

