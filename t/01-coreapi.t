
use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::StructuredObject;
use Test::Exception;
use Test::Without::Module qw( File::Tempdir::Capture::Plugin::Dir );

my $mock = Test::MockObject->new();
$mock->fake_module( "Example::Class", DOES => sub { 1 } );
$mock->mock( add_file      => sub { 1 } );
$mock->mock( adopt         => sub { 1 } );
$mock->mock( error_handler => sub { 1 } );
$mock->mock( inject        => sub { 1 } );

$mock->fake_new("Example::Class");

my $mock2 = Test::MockObject->new();
$mock2->fake_module( "Bad::Class", DOES => sub { 0 } );

my $mock3 = Test::MockObject->new();
$mock3->fake_module( "File::Tempdir::Capture::Plugin::Foo", DOES => sub { 1 } );
$mock3->mock( add_file      => sub { 1 } );
$mock3->mock( adopt         => sub { 1 } );
$mock3->mock( error_handler => sub { 1 } );
$mock3->mock( inject        => sub { 1 } );

$mock3->fake_new("File::Tempdir::Capture::Plugin::Foo");

my $ctx;    #= File::Tempdir::Capture->new();

testsuite(
  test { use_ok('Example::Class') },
  test { use_ok('File::Tempdir::Capture') },
  test { $ctx = new_ok( 'File::Tempdir::Capture', [], 'Create' ) },
  testgroup(
    "deathtests" => (
      (
        test {
          dies_ok { $ctx->add_file( 'example', { with => 'Bad::Class' } ) } 'Must DO things';
        },
        test {
          dies_ok { $ctx->add_file( 'example', { with => 'NonExisting::Class' } ) } 'Must Exist';
        },
        test {
          dies_ok { $ctx->add_file( 'example', { with => '::NonExisting' } ) } 'Must Exist after expanding';
        },
        test {
          dies_ok { $ctx->adopt('missing') } "Fail becuase plugin gone *and* no hashref";
        },
      ) x 2
    ),
  ),
  testgroup(
    "Lazy Load Coverage" => (
      test {
        lives_ok { $ctx->add_file( 'example', { with => 'File::Tempdir::Capture::Plugin::Foo' } ) };
      },
      test {
        lives_ok { $ctx->add_file( 'example', { with => '::Foo' } ) };
      },

    )
  ),
  testgroup(
    "No Death Tests" => (
      testgroup(
        "add_file" => (
          test {
            lives_ok {
              $ctx->add_file( 'example', { with => 'Example::Class' } );
            }
            'add_file';
          },
          test {
            $mock->called_pos_ok( -1, 'add_file' );
          },
          test {
            $mock->called_args_pos_is( -1, 2, 'example' );
          },
        )
      ),
      testgroup(
        "adopt" => (
          test {
            lives_ok {
              $ctx->adopt( 'example', { with => 'Example::Class' } );
            }
            'adopt';
          },
          test {
            $mock->called_pos_ok( -1, 'adopt' );
          },
          test {
            $mock->called_args_pos_is( -1, 2, 'example' );
          },
        )
      ),
      testgroup(
        "error_handler" => (
          test {
            lives_ok {
              $ctx->error_handler( 'example', { with => 'Example::Class' } );
            }
            'error_handler',;
          },
          test {
            $mock->called_pos_ok( -1, 'error_handler' );
          },
          test {
            $mock->called_args_pos_is( -1, 2, 'example' );
          },
        )
      ),
      testgroup(
        "inject" => (
          test {
            lives_ok {
              $ctx->inject( 'example', { with => 'Example::Class' } );
            }
            'inject';
          },
          test {
            $mock->called_pos_ok( -1, 'inject' );
          },
          test {
            $mock->called_args_pos_is( -1, 2, 'example' );
          },
        )
      ),
    )
  ),

  #)->linearize->run();
)->run();
