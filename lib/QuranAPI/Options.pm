package QuranAPI::Options;
use Mojo::Base 'Mojolicious::Plugin'; has 'app';

sub register {
    my ( $self, $app, $opts ) = @_;
    $self->app( $app );
    $app->helper( _options => sub { $self } );
}

=head2 default

the "default" suggested options ( language, quran, content, audio )

=cut

sub default {
    my $self = shift;
    my %hash;

    $hash{audio} = $self->app->cache( join( '.', qw/options default audio/ ) => sub {
        my $id = $self->app->db->query( qq|
            select r.reciter_id id
              from audio.reciter r
             where english = ?
        |, 'AbdulBaset AbdulSamad - Mujawwad' )->list; # TODO: normalize audio/reciter/recitation and use a slug instead -- b/c what happens if I change casing? ack
        return $id;
    } );

    $hash{quran} = $self->app->cache( join( '.', qw/options default quran/ ) => sub {
        my $id = $self->app->db->query( qq|
            select r.resource_id id
              from content.resource r
             where r.type = 'quran'
               and r.sub_type = 'text'
               and r.slug = 'ayah_text_regular'
        | )->list;
        return $id;
    } );

    $hash{language} = 'en'; # TODO: determine from http headers or geolocation

    $hash{content} = $self->app->cache( join( '.', qw/options default content/, $hash{language} ) => sub {
        my $id = $self->app->db->query( qq|
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
        return $id;
    } );

    return wantarray ? %hash : \%hash;
}

=head2 language

=cut

sub language {
    my $self = shift;
    my $list = $self->app->cache( join( '.', qw/options language/ ) => sub {
        my $list = $self->app->db->query( qq|
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
        return $list;
    } );
    return wantarray ? @{ $list } : $list;
}

=head2 quran

=cut

sub quran {
    my $self = shift;
    my $list = $self->app->cache( join( '.', qw/options quran/ ) => sub {
        my $list = $self->app->db->query( qq|
            select r.resource_id id
                 , r.sub_type "type"
                 , r.cardinality_type cardinality
                 , r.language_code "language"
                 , r.slug
                 , r.is_available
                 , r.description
                 , r.name
              from content.resource r
              join content.resource_api_version v using ( resource_id )
             where r.type = 'quran'
               and v.v2_is_enabled
             order by r.resource_id
        | )->hashes;
        return $list;
    } );
    return wantarray ? @{ $list } : $list;
}

=head2 content

a list of content options

=cut

sub content {
    my $self = shift;
    my $list = $self->app->cache( join( '.', qw/options content/ ) => sub {
        my $list = $self->app->db->query( qq|
            select r.resource_id id
                 , r.sub_type "type"
                 , r.cardinality_type cardinality
                 , r.language_code "language"
                 , r.slug
                 , r.is_available
                 , r.description
                 , r.name
              from content.resource r
              join content.resource_api_version v using ( resource_id )
             where r.type = 'content'
               and v.v2_is_enabled
             order by r.resource_id
        | )->hashes;
        return $list;
    } );
    return wantarray ? @{ $list } : $list;
}

=head2 audio

=cut

sub audio {
    my $self = shift;
    my $list = $self->app->cache( join( '.', qw/options audio/ ) => sub {
        my $list = $self->app->db->query( qq|
            select r.reciter_id id
                 , concat( 'http://audio.quran.com:9999/', r.path, '/ogg/' ) base_url
                 , r.arabic name_arabic
                 , r.english name_english
              from audio.reciter r
             order by r.english
        | )->hashes;
        return $list;
    } );
    return wantarray ? @{ $list } : $list;
}

# ABSTRACT: provides options
1
__END__
