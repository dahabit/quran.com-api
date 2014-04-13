package QuranAPI::Options::Language;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;
    my $list = $self->db->query( qq|
        select l.language_code id
             , l.unicode name_unicode
             , l.english name_english
             , l.direction
          from content.resource r
          join content.resource_api_version v using ( resource_id )
          join i18n.language l using ( language_code )
         where v.v2_is_enabled
           and r.is_available
         group by l.language_code, l.unicode, l.english, l.direction
         order by l.language_code
    | )->hashes;
    $self->render( json => $list );
}

1;
# ABSTRACT: Exports available language options
