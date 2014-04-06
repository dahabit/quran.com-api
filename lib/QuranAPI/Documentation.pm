package QuranAPI::Documentation;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;
    $self->render( text => 'documentation to go here' );
}

1;
# ABSTRACT: Documentation will go here
