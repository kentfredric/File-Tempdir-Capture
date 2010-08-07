use strict;
use warnings;

package File::Tempdir::Capture;

#ABSTRACT: Capture changes performed by system() calls in a temporary directory
#

=head1 SYNOPSIS

=head2 With arbitrary data.

    use File::Tempdir::Capture;
    my $containment = File::Tempdir::Capture->new();
    $containment->add_file( 'Makefile.PL' , {
        content => 'I would put some actual code here, but you get the idea',
    });
    $containment->add_file( 'lib/Foo.pm', {
        content => 'package Foo; use strict; use warnings; 1; '
    });
    $containment->add_file( 'lib/Foo/Bar.pm', {
        source => '/home/myname/lib/Foo/Bar.pm',
    });
    $containment->add_file( 'lib/Foo/Baz.pm', {
        code => \&generate_baz,
    });
    $containment->adopt( '/home/sources/foobazzle/', { with => '::DirReader' } );
    $containment->error_handler(sub{
        my ( $self, @errors );
        warn "HURP, Fail. Bash time!";
        system("bash");
    });
    my $results = $containment->run(sub{
        system($^X, "Makefile.PL") and die;
        system("make") and die;
    });
    $containment->adopt( $results, { with => "::Selector::Update" } );
    $containment->inject('/home/build/foopackage/', { with => "::DirWriter" } );
    $containment->inject('/home/build/foopackage.tar.bz2' , { with => "::TarBuilder" } );

=head2 With existing file collections

    use File::Tempdir::Capture;

    my $containment = File::Tempdir::Capture->new();
    $containment->adopt( $zilla , { with => '::DistZilla' } );
    $containment->error_handler(sub{
        my ( $self, @errors ) = @_;
        warn "Problem executing capturey in temporary directory, ";
        warn "launching a shell in that directory to inspect the problem, ";
        warn "exit your shell when finished to clean the temporary directory";
        system('bash');
    });
    my $results = $containment->run(sub{
        system($^X , 'Makefile.PL' ) and die;
    });
    $containment->adopt( $results, { with => "::Selector", callback => sub {
        my ( $file ) = @_;
        # Capture only modified files
        # but ignore deletions and creations.
        return 1 if $file->is_modified;
        return 0 if $file->is_new;
        return 0 if $file->is_deleted;
        return 1 if $file->is_original;
    });
    $containment->inject( $zilla , { with => "::DistZilla" } );

=cut

=head1 DESCRIPTION

This modules goal is to steal and re-centralise all the bits that make Dist::Zilla::Role::Tempdir function
in a more re-usable way.

When transition is complete, this module permits one to do as following:

=over 4

=item 1. Generate an In-Memory file structure using code

=item 2. Serialize that file structure out to a temporary directory

=item 3. Execute their choice of shell code in the directory

=item 4. Detect What changes have been made

=item 5. Selectively reintegrate files back into an in-memory file-structure.

=back

=cut

=head1 GENERAL FORM

Many methods in this module have the general form:

    $object->$method( @arglist , $confighash );

The configuration hash is optional, and only needed if you want to do non-default things.

This naturally expands to doing:

    File::Tempdir::Capture::Plugin::{$default}->new({ %$confighash, capture => $object })->$method( @arglist );

( with a bit of auto-load magic )

You can override the default value for the plug-in using the 'with' key of the configuration hash, as follows:

    $object->$method( @arglist, { with => $pluginname });

Where C<< $pluginname >> can be as follows:

    ::Foo::Bar  # leading :: indicates its a File::Tempdir::Capture::Plugin::
    Baz::Quux   # literal package name

Either should work the right way.

=cut

use Moose 1.09;

has _file_stash => (
  isa      => 'HashRef',
  is       => 'rw',
  required => 1,
  default  => sub { +{} },
  traits   => [qw( Hash )],
  handles  => {
    file_set    => 'set',
    file_get    => 'set',
    file_delete => 'delete',
    file_names  => 'keys',
    file_exists => 'exists',
  },
);
## no critic ( Subroutines::RequireArgUnpacking )
sub _error {
  require Carp;
  Carp::croak(@_);
}
## use critic

sub _params {
  my ($args) = @_;

  my $self = shift @{$args};

  my $config = {};
  if ( ref $args->[-1] eq 'HASH' ) {
    $config = pop @{$args};
  }
  return ( $self, $config, @{$args} );
}

{
  my $plugin_cache = {};

  sub _require_plugin {
    my ( $self, $config, $default, $role ) = @_;
    my ( $pluginname, $module );
    my $prefix   = 'File::Tempdir::Capture::Plugin';
    my $hascolon = qr/^::/msix;

    if ( not exists $config->{with} ) {
      $pluginname = $default;
    }
    else {
      $pluginname = $config->{with};
    }

    if ( exists $plugin_cache->{$pluginname} ) {
      $module = $plugin_cache->{$pluginname};
    }
    elsif ( $pluginname =~ $hascolon and exists $plugin_cache->{ $prefix . $pluginname } ) {
      $module = $plugin_cache->{$pluginname} = $plugin_cache->{ $prefix . $pluginname };
    }
    else {
      $module = $pluginname;
      $module = $prefix . $pluginname if $pluginname =~ $hascolon;

      # STOLEN From perl5i::2::SCALAR->module2path
      # version 2.3.1 -- kentnl 2010-08-08

      my @parts = split /::/msx, $module;
      my $file = join q{/}, @parts;
      $file .= '.pm';
      require $file;
      $plugin_cache->{$module}     = $module;
      $plugin_cache->{$pluginname} = $module;
    }
    if ( $module->DOES( $prefix . q[::] . $role ) ) {
      return $module;
    }
    return _error("Sorry, the module \"$module\" ( plugin \"$pluginname\" ) does not DO {$prefix}::{$role}");
  }
}
## use critic

=method add_file

    $o->add_file( @args );
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::File->new({ capture => $o });
    # $c->add_file( @args );
    $o->add_file( @args, { with => '::FooBar' , param => 'Baz' });
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::FooBar->new(  { with => '::FooBar' , param => 'Baz' , capture => $o } );
    # $c->add_file( @args );

=cut

## no critic ( Subroutines::RequireArgUnpacking )
sub add_file {
  my ( $self, $config, @rest ) = _params( \@_ );
  my $module = $self->_require_plugin( $config, '::File', 'FileGenerator' );
  $module->new( +{ %{$config}, capture => $self } )->add_file(@rest);

  return $self;
}

=method adopt

    $o->adopt_file( @args );
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::Dir->new({ capture => $o });
    # $c->adopt( @args );
    $o->adopt( @args, { with => '::FooBar' , param => 'Baz' });
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::FooBar->new(  { with => '::FooBar' , param => 'Baz' , capture => $o } );
    # $c->adopt_file( @args );

=cut

sub adopt {
  my ( $self, $config, @rest ) = _params( \@_ );
  my $module = $self->_require_plugin( $config, '::Dir', 'StashAdopter' );
  $module->new( +{ %{$config}, capture => $self } )->adopt(@rest);
  return $self;
}

=method error_handler

    $o->error_handler( @args );
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::CodeError->new({ capture => $o });
    # $c->error_handler( @args );
    $o->error_handler( @args, { with => '::FooBar' , param => 'Baz' });
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::FooBar->new(  { with => '::FooBar' , param => 'Baz' , capture => $o } );
    # $c->error_handler( @args );

=cut

sub error_handler {
  my ( $self, $config, @rest ) = _params( \@_, );
  my $module = $self->_require_plugin( $config, '::CodeError', 'ErrorHandler' );
  $module->new( +{ %{$config}, capture => $self } )->error_handler(@rest);
  return $self;
}

=method inject

    $o->inject( @args );
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::Dir->new({ capture => $o });
    # $c->inject( @args );
    $o->inject( @args, { with => '::FooBar' , param => 'Baz' });
    # shorthand for
    # my $c = File::Tempdir::Capture::Plugin::FooBar->new(  { with => '::FooBar' , param => 'Baz' , capture => $o } );
    # $c->inject( @args );

=cut

sub inject {
  my ( $self, $config, @rest ) = _params( \@_, );
  my $module = $self->_require_plugin( $config, '::Dir', 'StashInjecter' );
  $module->new( +{ %{$config}, capture => $self } )->inject(@rest);
  return $self;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
