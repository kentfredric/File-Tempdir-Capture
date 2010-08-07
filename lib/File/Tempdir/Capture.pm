use strict;
use warnings;
package File::Tempdir::Capture;
#ABSTRACT: Capture changes performed by system() calls in a tempdir

=head1 DESCRIPTION

This modules goal is to steal and recentralise all the bits that make Dist::Zilla::Role::Tempdir function
in a more reusalbe way.

When theivery is complete, this module permits one to do as following:

=over 4

=item 1. Generate an In-Memory file structure using code

=item 2. Serialize that file structure out to a temporary directory

=item 3. Execute their choice of shell code in the directory

=item 4. Detect What changes have been made

=item 5. Selectively reintegrate files back into an in-memory file-structure.

=back

1;
