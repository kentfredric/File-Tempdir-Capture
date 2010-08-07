use strict;
use warnings;

package File::Tempdir::Capture;

#ABSTRACT: Capture changes performed by system() calls in a temporary directory
#
=head1 SYNOPSIS

    use File::Tempdir::Capture;

    my $containment = File::Tempdir::Capture;
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

When theivery is complete, this module permits one to do as following:

=over 4

=item 1. Generate an In-Memory file structure using code

=item 2. Serialize that file structure out to a temporary directory

=item 3. Execute their choice of shell code in the directory

=item 4. Detect What changes have been made

=item 5. Selectively reintegrate files back into an in-memory file-structure.

=back

=cut

1;
