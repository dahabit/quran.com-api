package QuranAPI::Content::Tafsir;
use Mojo::Base 'Mojolicious::Controller';

sub hash {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, $self->args );

    my $hash = $self->cache( join( '.', qw/content tafsir/, $args{tafsir_id} ) => sub {
        my $hash = $self->db->query( qq|
            select c.text
              from content.tafsir c
             where c.tafsir_id = ?
        |, $args{tafsir_id} )->hash;
        return $hash;
    } );
    $self->render( json => $hash );
}

# ABSTRACT: surah info
1;
