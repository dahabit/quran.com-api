package QuranAPI::Options::Languages;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;
    my $list = $self->db->query( qq|
        select l.language_code id
             , l.unicode name_unicode
             , l.english name_english
             , l.direction
          from content.resource r
          join i18n.language l using ( language_code )
         group by l.language_code, l.unicode, l.english, l.direction
         order by l.language_code
    | )->hashes;
    $self->render( json => $list );
}

1;
# ABSTRACT: Exports available language options
