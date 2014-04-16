package QuranAPI::Options::Default;
use Mojo::Base 'Mojolicious::Controller';

sub hash {
    my $self = shift;
    $self->render( json => $self->defaults );
}

sub defaults {
    my $self = shift;
    my %hash;

    $hash{audio} = $self->db->query( qq|
        select r.reciter_id id
          from audio.reciter r
         where english = ?
    |, 'AbdulBaset AbdulSamad - Mujawwad' )->list; # TODO: normalize audio/reciter/recitation and use a slug instead -- b/c what happens if I change casing? ack

    $hash{quran} = $self->db->query( qq|
        select r.resource_id id
          from content.resource r
         where r.type = 'quran'
           and r.sub_type = 'text'
           and r.slug = 'ayah_text_minimal'
    | )->list;

    $hash{language} = 'en';

    $hash{content} = $self->db->query( qq|
        select r.resource_id id
          from content.resource r
          join content.resource_api_version v using ( resource_id )
         where r.type = 'content'
           and r.sub_type in ( 'translation', 'tafsir' )
           and r.cardinality_type = '1_ayah'
           and r.is_available
           and r.language_code = ?
           and v.v2_is_enabled
         order by v.v2_weighted desc, r.resource_id
         limit 1
    |, $hash{language} )->list;

    return \%hash;
}

# ABSTRACT: Returns suggested default parameters to send to the /ayat endpoint.
1;
__END__

=head1 USAGE

=cut
