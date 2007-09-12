#!/usr/bin/perl

package Devel::Events::Objects;

use strict;
use warnings;

our $VERSION = "0.01";

__PACKAGE__;

__END__

=pod

=head1 NAME

Devel::Events::Objects - Object tracking support for L<Devel::Events>

=head1 SYNOPSIS

	use Devel::Cycle;
	use Data::Dumper;

	use Devel::Events::Handler::ObjectTracker;
	use Devel::Events::Filter::RemoveFields;
	use Devel::Events::Generator::Objects;

	my $tracker = Devel::Events::Handler::ObjectTracker->new();

	my $gen = Devel::Events::Generator::Objects->new(
		handler => Devel::Events::Filter::RemoveFields->new(
			fields => [qw/generator/], # don't need to have a ref to $gen in each event
			handler => $tracker,
		),
	);

	$gen->enable(); # start generating events

	$code->(); # check for leaks in this code

	$gen->disable();

	# live_objects is a Tie::RefHash::Weak hash

	my @leaked_objects = keys %{ $tracker->live_objects };

	print "leaked ", scalar(@leaked_objects), " objects\n";

	foreach my $object ( @leaked_objects ) {
		print "Leaked object: $object\n";

		# the event that generated it
		print Dumper( $object, $tracker->live_object->{$object} );

		find_cycle( $object );
	}

=head1 DESCRIPTION

This package provides an event generator and a handler for L<Devel::Events>,
that facilitate leak checking.

=cut


