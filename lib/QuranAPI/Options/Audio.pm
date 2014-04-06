package QuranAPI::Options::Audio;

sub list {
    my $self = shift;
    my $list = $self->db->query( qq|
        select r.reciter_id id
             , concat( 'http://audio.quran.com:9999/', r.path, '/ogg/' ) base_url
             , r.arabic name_arabic
             , r.english name_english
          from audio.reciter r
         order by r.english
    | )->hashes;
    $self->render( json => $list );
}

1;
# ABSTRACT: Exports available verse audio options
