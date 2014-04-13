package QuranAPI::Bucket::Ayat;
use Mojo::Base 'QuranAPI::Bucket';

sub list {
    my $self = shift;
    my %args = $self->args;

    my @list;
    push @list, \%args;

    $self->render( json => \@list );
}

# ABSTRACT: Pass in options hash, get the data returned for the specified surah and ayah range
1;
__END__

=head1 USAGE

=cut
