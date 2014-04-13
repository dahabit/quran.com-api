package QuranAPI::Bucket::Page;
use Mojo::Base 'QuranAPI::Bucket';

sub list {
    my $self = shift;
    my %args = $self->args;

    my @list;
    push @list, \%args;

    $self->render( json => \@list );
}

# ABSTRACT: Pass in options hash, get the data returned for the specified page
1;
__END__

=head1 USAGE

foo

=cut
