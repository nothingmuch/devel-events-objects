#!/usr/bin/perl

package Devel::Events::Generator::Objects;

my $SINGLETON;

BEGIN {
	# before Moose or anything else is parsed, we overload CORE::GLOBAL::bless
	# this will divert bless to an object of our choosing if that variable is filled with something

	*CORE::GLOBAL::bless = sub {
		if ( defined $SINGLETON ) {
			return $SINGLETON->bless(@_);
		} else {
			_core_bless(@_);
		}
	}
}

sub _core_bless {
	my ( $data, $class ) = @_;
	$class = caller unless defined $class;
	CORE::bless($data, $class);
}

use Moose;

with qw/Devel::Events::Generator/;

use Carp qw/croak/;
use Variable::Magic qw/cast getdata/;
use Scalar::Util qw/reftype blessed weaken/;

{
	no warnings 'redefine';

    # for some reason this breaks at compile time
    # we need this version to preserve errors though
	# hopefully no bad calls to bless() are made during the loading of Moose

	*_core_bless = sub {
		my ( $data, $class ) = @_;
		$class = caller unless defined $class;

		my ( $object, $e );
		
		{
			local $@;
			$object = eval { CORE::bless($data, $class) };
			$e = $@;
		}

		unless ( $e ) {
			return $object;
		} else {
			my $line = __LINE__ - 7;
			my $file = quotemeta(__FILE__);

			$e =~ s/ at $file line $line\.\n$//o;

			croak($e);
		}
	};
}

sub enable {
	my $self = shift;
	$SINGLETON = $self;
	weaken($SINGLETON);
}

sub disable {
	$SINGLETON = undef;
}

sub bless {
	my ( $self, $data, $class ) = @_;
	$class = caller unless defined $class;

	my $old_class = blessed($data);

	my $object = _core_bless( $data, $class );

	require Carp::Heavy;
	my $i = Carp::short_error_loc();
	my ( $pkg, $file, $line ) = caller($i);

	$self->object_bless(
		$object,
		old_class => $old_class,
		'package' => $pkg,
		file      => $file,
		line      => $line,
	);

	return $object;
}


sub object_bless {
    my ( $self, $object, @args ) = @_;

	$self->generate_event( object_bless => object => $object, @args );
	
	$self->track_object($object);
}

sub object_destroy {
	my ( $self, $object, @args ) = @_;

	$self->generate_event( object_destroy => object => $object, @args );

	$self->untrack_object( $object );
}

sub generate_event {
	my ( $self, $type, @event ) = @_;

	$self->send_event( $type => ( @event, generator => $self ) );
}

use constant tracker_magic => Variable::Magic::wizard(
	free => sub {
		my ( $object, $objs ) = @_;
		foreach my $self ( @{ $objs || [] } ) {
			$self->object_destroy( $object ) if defined $self; # might disappear in global destruction
		}
	},
	data => sub {
		my ( $object, $self ) = @_;
		return $self;
	},
);

sub track_object {
	my ( $self, $object ) = @_;


	my $objects;

	# blech, any idea how to clean this up?

	my $wiz = $self->tracker_magic($object);

	if ( reftype $object eq 'SCALAR' ) {
		$objects = getdata( $$object, $wiz )
			or cast( $$object, $wiz, ( $objects = [] ) );
	} elsif ( reftype $object eq 'HASH' ) {
		$objects = getdata ( %$object, $wiz )
			or cast( %$object, $wiz, ( $objects = [] ) );
	} elsif ( reftype $object eq 'ARRAY' ) {
		$objects = getdata ( @$object, $wiz )
			or cast( @$object, $wiz, ( $objects = [] ) );
	} elsif ( reftype $object eq 'GLOB' or reftype $object eq 'IO' ) {
		$objects = getdata ( *$object, $wiz )
			or cast( *$object, $wiz, ( $objects = [] ) );
	} else {
		die "patches welcome";
	}

	unless ( grep { $_ eq $self } @$objects ) {
		push @$objects, $self;
		weaken($objects->[-1]);
	}
}

sub untrack_object {
	my ( $self, $object );

	return;
}


__PACKAGE__;

__END__

=pod

=head1 NAME

Devel::Events::Generator::Objects - Generate events for C<bless>ing and
destruction of objects.

=head1 SYNOPSIS

	use Devel::Events::Generator::Objects; # must be loaded before any code you want to instrument

	my $g = Devel::Events::Generator::Objects->new(
		handler => $h,
	);

	$g->enable(); # only one Objects generator may be enabled at a time

	$code->(); # objects being created and destroyed cause events to be generated

	$g->disable();

=head1 DESCRIPTION

This module overrides C<CORE::GLOBAL::bless> on load. The altered version will
delegate back to the original version until an instance of a generator is enabled.

When a generator is enabled (only one L<Devel::Events::Generator::Objects>
instance may be enabled at a time. Use L<Devel::Events::Handler::Multiplex> to
dup events to multiple listeners), the overridden version of C<bless> will
cause an C<object_bless> event to fire, and will also attach magic to the
object to keep track of it's destruction using L<Variable::Magic>.

When the object is freed by the interpreter an C<object_destroy> event is
fired. Unfortunately by this time C<perl> has already unblessed the object in
question, so in order to keep track of the class you must associate it yourself
with the reference address.

L<Devel::Events::Handler::ObjectTracker> contains a detailed usage example.

=head1 METHODS

=over 4

=item enable

Make this instance the enabled one (disabling any other instance which is
enabled).

This only applies to the C<object_bless> method.

=item disable

Disable this instance. Will stop generating C<object_bless> events.

=item bless

The method called by the C<CORE::GLOBAL::bless> hook.

Uses C<CORE::bless> to bless the data, and then calls C<object_bless>.

=item object_bless

Generates the C<object_bless> event.

Calls C<rack_object>.

=item object_destroy

Generates the C<object_destroy> event.

Calls C<untrack_object>.

=item generate_event

Convenience method used by the previous two methods.

=item tracker_magic

A class method containing the L<Variable::Magic> specification necessary for
L<track_object> to work.

=item track_object

Attach magic to an object that will call C<object_destroy> when the data is
about to be freed.

=item untrack_object

Currently empty. A subclass with a different implementation of C<track_object>
might want to override this.

=back

=head1 SEE ALSO

L<Devel::Object::Leak>, L<Variable::Magic>

=cut
