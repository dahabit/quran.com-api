package QuranAPI::Bucket;
use Mojo::Base 'QuranAPI::Options::Default';

sub keys_for_ayat {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );
}

sub keys_for_page {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );
}

# ABSTRACT: DNR principle
1;
__END__

=head1 SYNOPSIS

=cut
