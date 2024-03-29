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
            select t.recitation_id id
              from audio.recitation t
              join audio.reciter r using ( reciter_id )
              left join audio.style s using ( style_id )
             where t.is_enabled
               and r.slug = 'abdulbaset'
               and s.slug = 'mujawwad'
        | )->list;
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
        for my $item ( @{ $list } ) {
            my %mash;
               $mash{name}    = [ qw/english unicode/ ];
            for my $pfix ( keys %mash ) {
                my ( @grep, %hash );
                @grep = grep { $_ =~ /^${pfix}_/ } keys %{ $item };
                for my $orig ( @grep ) {
                    my $attr = $orig;
                       $attr =~ s/^${pfix}_//;
                    $hash{ $attr } = delete $item->{ $orig };
                }
                delete $hash{ $_ } for grep { not defined $hash{ $_ } } keys %hash;
                $item->{ $pfix } = \%hash if keys %hash;
            }
        }
        return $list;
    } );
    return wantarray ? @{ $list } : $list;
}

=head2 quran

=cut

sub quran {
    my ( $self, %args, %opts, @args, @opts ) = @_;
    $opts{id} = "r.resource_id";
    $opts{type} = "r.sub_type";
    $opts{cardinality} = "r.cardinality_type";
    $opts{language} = "r.language_code";
    $opts{ $_ } = "r.$_" for qw/slug is_available description name/;
    for my $key ( sort keys %opts ) {
        next unless exists $args{ $key };
        push @opts, $opts{ $key };
        push @args, $args{ $key };
    }
    my $list = $self->app->cache( join( '.', qw/options quran/ ) => sub {
        my $list = $self->app->db->query( qq|
            select r.resource_id id
                 , r.sub_type "type"
                 , r.cardinality_type cardinality
                 , r.slug
                 , r.is_available
                 , r.description
                 , r.name
              from content.resource r
              join content.resource_api_version v using ( resource_id )
             where r.type = 'quran'
               and v.v2_is_enabled|.( !@opts ? '' : ' and '. join ' and ', map { "$_ = ?" } @opts ).qq|
             order by r.resource_id
        |, @args )->hashes;
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
            select t.recitation_id id
                 , t.reciter_id
                 , t.style_id
                 , r.slug reciter_slug
                 , s.slug style_slug
                 , concat_ws( ' ', r.english, case when ( s.english is not null ) then concat( '(', s.english, ')' ) end ) name_english
                 , concat_ws( ' ', r.arabic, case when ( s.arabic is not null ) then concat( '(', s.arabic, ')' ) end ) name_arabic
              from audio.recitation t
              join audio.reciter r using ( reciter_id )
              left join audio.style s using ( style_id )
             where t.is_enabled
             order by r.english, s.english, t.recitation_id
        | )->hashes;
        for my $item ( @{ $list } ) {
            my %mash;
               $mash{reciter} = [ qw/id slug/ ];
               $mash{style}   = [ qw/id slug/ ];
               $mash{name}    = [ qw/english arabic/ ];
            for my $pfix ( keys %mash ) {
                my ( @grep, %hash );
                @grep = grep { $_ =~ /^${pfix}_/ } keys %{ $item };
                for my $orig ( @grep ) {
                    my $attr = $orig;
                       $attr =~ s/^${pfix}_//;
                    $hash{ $attr } = delete $item->{ $orig };
                }
                delete $hash{ $_ } for grep { not defined $hash{ $_ } } keys %hash;
                $item->{ $pfix } = \%hash if keys %hash;
            }
        }
        return $list;
    } );
    return wantarray ? @{ $list } : $list;
}

# ABSTRACT: provides options
1
__END__
