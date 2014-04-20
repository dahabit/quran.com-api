package QuranAPI::Bucket;
use Mojo::Base 'Mojolicious::Controller';
use List::AllUtils qw/uniq/;

sub keys_for_ayat {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );
    my $keys = $self->cache( join( '.', qw/bucket keys for ayat/, $args{surah}, $args{range}[0], $args{range}[1] ) => sub {
        my @keys = $self->db->query( qq|
            select a.ayah_key
              from quran.ayah a
             where a.surah_id = ?
               and a.ayah_num >= ?
               and a.ayah_num <= ?
             order by a.surah_id, a.ayah_num
        |, $args{surah}, $args{range}[0], $args{range}[1] )->flat;
        return \@keys;
    } );
    return wantarray ? @{ $keys } : $keys;
}

sub keys_for_page {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );
    my $keys = $self->cache( join( '.', qw/bucket keys for page/, $args{page}[0], $args{page}[1] ) => sub {
        my @keys = $self->db->query( qq|
            select a.ayah_key
              from quran.ayah a
             where a.page_num >= ?
               and a.page_num <= ?
             order by a.surah_id, a.ayah_num
        |, $args{page}[0], $args{page}[1] )->flat;
        return \@keys;
    } );
    return wantarray ? @{ $keys } : $keys;
}

sub bucket {
    my ( $self, %args ) = @_;
    my ( @keys, @list );
    my ( %vars, %rows );

    %vars = %{ $args{vars} };
    @keys = @{ $args{keys} };

    for my $ayah_key ( @keys ) {
        my ( $surah, $ayah ) = map { int $_ } split /:/, $ayah_key;
        my ( %hash );
        $hash{surah} = $surah;
        $hash{ayah} = $ayah;
        push @list, \%hash;
    }

    my %cache_opts;
    dont_cache_weird_ranges: { # the math is weird here, but it basically checks if the request is "regular," i.e. pull ayat blocks of n size, e.g. 12 at a time, 20 at a time, etc.
        my $do_not_cache = 0;
        if ( $vars{surah} and $vars{range} ) { # ((min-1)%(max-min)) or max-min <= 50 && max == reallymax
            my $max = $self->cache( join( '.', qw/max/, $vars{surah} ) => sub {
                return $self->db->query( qq|
                    select max( ayah_num ) "max"
                      from quran.ayah
                     where surah_id = ?
                |, $vars{surah} )->list;
            } );
            $do_not_cache = !( !( ( $vars{range}[0] - 1 ) % ( $vars{range}[1] - $vars{range}[0] ) ) ||
                                ( ( $vars{range}[1] - $vars{range}[0] ) <= 50 && $vars{range}[1] == $max ) ) ? 1 : 0;
        }
        elsif ( $vars{page} ) {
            $do_not_cache = !( $vars{page}[0] == $vars{page}[1] ) ? 1 : 0;
        }
        $self->debug( 'do_not_cache? '. $do_not_cache );
        $cache_opts{expires_in} = time - 1 if $do_not_cache;
    };

    quran: { next unless defined $vars{quran};
        $rows{ 'resource.quran' } = $self->cache( join( '.', qw/resource quran/, $vars{quran} ) => sub {
            my $hash = $self->db->query( qq|
                select r.*
                  from content.resource r
                  join content.resource_api_version v using ( resource_id )
                 where r.is_available
                   and v.v2_is_enabled
                   and r.type = 'quran'
                   and r.resource_id in ( ? )
            |, $vars{quran} )->hash;
            return $hash;
        } );

        if ( my $row = $rows{ 'resource.quran' } ) {
            my $join;
            if ( $row->{cardinality_type} eq '1_word' ) {
                $join = "join $row->{type}.$row->{slug} c using ( resource_id )";
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
                $join = "join $row->{type}.$row->{sub_type} c using ( resource_id )";
            }

            if ( $row->{cardinality_type} eq '1_word' ) {
                $vars{language} //= $self->_options->default->{language};
                my $result = $self->cache( join( '.', '1_word', $vars{language}, $row->{resource_id}, @keys ) => sub {
                    my %result;
                    my %cut;
                    if ( $row->{slug} eq 'word_font' ) {
                        $cut{select} = qq|
                             , concat( 'p', xc.page_num ) char_font
                             , concat( '&#x', xc.code_hex, ';' ) char_code
                             , xt.name char_type
                        |;
                        $cut{join} = qq|
                          join complex.char xc on xc.char_id = c.char_id
                          join complex.type xt on xt.type_id = xc.type_id
                        |;
                    }
                    my @result = $self->db->query( qq|
                        select c.* $cut{select}
                             , ct.value word_translation
                             , ca.value word_arabic
                             , cl.value word_lemma
                             , cr.value word_root
                          from content.resource r $join
                          join quran.ayah a using ( ayah_key ) $cut{join}
                          left join corpus.word w on w.word_id = c.word_id
                          left join corpus.translation ct on w.word_id = ct.word_id and ct.language_code = ?
                          left join corpus.arabic ca on w.arabic_id = ca.arabic_id
                          left join corpus.lemma cl on w.lemma_id = cl.lemma_id
                          left join corpus.root cr on w.root_id = cr.root_id
                         where r.resource_id = ?
                           and a.ayah_key in ( |.( join ', ', map { '?' } @keys ).qq| )
                         order by a.surah_id, a.ayah_num
                             , c.position
                    |, $vars{language}, $row->{resource_id}, @keys )->hashes; # TODO the "word_arabic" value needs to be re-scraped, noticed at least one missing letter on a word in surat al-fatiha
                    for my $result ( @result ) {
                        my $resource_id   = delete $result->{resource_id};
                        my $ayah_key      = delete $result->{ayah_key};
                        my %mash_key;
                           $mash_key{word}  = [ qw/id root lemma arabic translation/ ];
                           $mash_key{char}  = [ qw/id type code font/ ];
                           $mash_key{image} = [ qw/id bloo blee blah/ ]; # TODO

                        for my $prefix ( keys %mash_key ) {
                            my ( @grep, %hash );
                            @grep = grep { $_ =~ /^${prefix}_/ } keys %{ $result };
                            for my $orig ( @grep ) {
                                my $attr = $orig;
                                   $attr =~ s/^${prefix}_//;
                                $hash{ $attr } = delete $result->{ $orig };
                            }
                            delete $hash{ $_ } for grep { not defined $hash{ $_ } } keys %hash;
                            $result->{ $prefix } = \%hash if keys %hash;
                        }

                        delete $result->{position};
                        push @{ $result{ $ayah_key } }, $result;
                    }
                    return \%result;
                }, %cache_opts ); # end cache
                for my $i ( 0 .. $#keys ) {
                    my $ayah_key = $keys[ $i ];
                    push @{ $rows{ 'result.quran' }{ $ayah_key } }, $result->{ $ayah_key } if $result->{ $ayah_key };
                }
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
                my $result = $self->cache( join( '.', '1_ayah', $row->{resource_id}, @keys ) => sub {
                    my %result;
                    my @result = $self->db->query( qq|
                        select c.*
                          from content.resource r $join
                          join quran.ayah a using ( ayah_key )
                         where r.resource_id = ?
                           and a.ayah_key in ( |.( join ', ', map { '?' } @keys ).qq| )
                         order by a.surah_id, a.ayah_num
                    |, $row->{resource_id}, @keys )->hashes;
                    for my $result ( @result ) {
                        my $resource_id = delete $result->{resource_id};
                        my $ayah_key    = delete $result->{ayah_key};
                        $result{ $ayah_key } = $result;
                    }
                    return \%result;
                }, %cache_opts ); # end cache
                for my $i ( 0 .. $#keys ) {
                    my $ayah_key = $keys[ $i ];
                    push @{ $rows{ 'result.quran' }{ $ayah_key } }, $result->{ $ayah_key } if $result->{ $ayah_key };
                }
            }
            for my $i ( 0 .. $#keys ) {
                my $ayah_key = $keys[ $i ];
                my $hash_ref = $list[ $i ];
                $hash_ref->{quran} = shift @{ $rows{ 'result.quran' }{ $ayah_key } }; # should only be one in this array anyway
            }
        }
    }; # quran {}

    content: { next unless defined $vars{content};
        $rows{ 'resource.content' } = $self->cache( join( '.', qw/resource content/, @{ $vars{content} } ) => sub {
            return $self->db->query( qq|
                select r.*
                  from content.resource r
                  join content.resource_api_version v using ( resource_id )
                 where r.is_available
                   and v.v2_is_enabled
                   and r.type = 'content'
                   and r.resource_id in ( |.( join ', ', map { '?' } @{ $vars{content} } ).qq| )
                 order by ( |.( join ', ', map { 'r.resource_id = ?' } @{ $vars{content} } ).qq| ) desc
            |, ( @{ $vars{content} }, @{ $vars{content} } ) )->hashes;
        } );

        for my $row ( @{ $rows{ 'resource.content' } } ) {
            my $join;
            if ( $row->{cardinality_type} eq 'n_ayah' ) {
                $join = "join $row->{type}.$row->{sub_type} c using ( resource_id ) join $row->{type}.$row->{sub_type}_ayah n using ( $row->{sub_type}_id )";
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
                $join = "join $row->{type}.$row->{sub_type} c using ( resource_id )";
            }

            if ( $row->{cardinality_type} eq 'n_ayah' ) {
                my $result = $self->cache( join( '.', 'n_ayah', $row->{resource_id}, @keys ) => sub {
                    my %result; # TODO http://api.v2.quran.com/ should be in hard config or soft derived
                    my @result = $self->db->query( qq|
                        select c.resource_id
                             , a.ayah_key
                             , concat( 'http://api.v2.quran.com/', concat_ws( '/', r.type, r.sub_type, c.$row->{sub_type}_id ) ) url
                          from content.resource r $join
                          join quran.ayah a using ( ayah_key )
                         where r.resource_id = ?
                           and a.ayah_key in ( |.( join ', ', map { '?' } @keys ).qq| )
                         order by a.surah_id, a.ayah_num
                    |, $row->{resource_id}, @keys )->hashes;
                    for my $result ( @result ) {
                        my $resource_id = delete $result->{resource_id};
                        my $ayah_key    = delete $result->{ayah_key};
                        $result{ $ayah_key } = $result;
                    }
                    return \%result;
                }, %cache_opts ); # end cache
                for my $i ( 0 .. $#keys ) {
                    my $ayah_key = $keys[ $i ];
                    push @{ $rows{ 'result.content' }{ $ayah_key } }, $result->{ $ayah_key } if $result->{ $ayah_key };
                }
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
                my $result = $self->cache( join( '.', '1_ayah', $row->{resource_id}, @keys ) => sub {
                    my %result;
                    my @result = $self->db->query( qq|
                        select c.*
                          from content.resource r $join
                          join quran.ayah a using ( ayah_key )
                         where r.resource_id = ?
                           and a.ayah_key in ( |.( join ', ', map { '?' } @keys ).qq| )
                         order by a.surah_id, a.ayah_num
                    |, $row->{resource_id}, @keys )->hashes;
                    for my $result ( @result ) {
                        my $resource_id = delete $result->{resource_id};
                        my $ayah_key    = delete $result->{ayah_key};
                        $result{ $ayah_key } = $result;
                    }
                    return \%result;
                }, %cache_opts ); # end cache
                for my $i ( 0 .. $#keys ) {
                    my $ayah_key = $keys[ $i ];
                    push @{ $rows{ 'result.content' }{ $ayah_key } }, $result->{ $ayah_key } if $result->{ $ayah_key };
                }
            }
        }

        for my $i ( 0 .. $#keys ) {
            my $ayah_key = $keys[ $i ];
            my $hash_ref = $list[ $i ];
            for my $result ( @{ $rows{ 'result.content' }{ $ayah_key } } ) {
                push @{ $hash_ref->{content} }, $result;
            }
        }
    }; # content {}

    audio: { next unless defined $vars{audio};
        my $result = $self->cache( join( '.', 'audio', $vars{audio}, @keys ) => sub {
            my %result;
            my @result = $self->db->query( qq|
                select a.ayah_key
                     , concat( 'http://audio.quran.com:9999/', concat_ws( '/', r.path, s.path, f.format, concat( replace( format('%3s', a.surah_id ), ' ', '0' ), replace( format('%3s', a.ayah_num ), ' ', '0' ), '.', f.format ) ) ) url
                     , f.duration
                     , f.mime_type
                  from audio.file f
                  join quran.ayah a using ( ayah_key )
                  join audio.recitation t using ( recitation_id )
                  join audio.reciter r using ( reciter_id )
                  left join audio.style s using ( style_id )
                 where t.recitation_id = ?
                   and a.ayah_key in ( |.( join ', ', map { '?' } @keys ).qq| )
                   and f.format = 'ogg'
                 order by a.surah_id, a.ayah_num
            |, $vars{audio}, @keys )->hashes;
            for my $result ( @result ) {
                my $ayah_key = delete $result->{ayah_key};
                $result{ $ayah_key } = $result;
            }
            return \%result;
        }, %cache_opts ); # end cache
        for my $i ( 0 .. $#keys ) {
            my $ayah_key = $keys[ $i ];
            push @{ $rows{ 'result.audio' }{ $ayah_key } }, $result->{ $ayah_key } if $result->{ $ayah_key };
        }
        for my $i ( 0 .. $#keys ) { # this second for loop is redundant but for the sake of consistency w/ the other sections above maybe?
            my $ayah_key = $keys[ $i ];
            my $hash_ref = $list[ $i ];
            $hash_ref->{audio} = shift @{ $rows{ 'result.audio' }{ $ayah_key } }; # should only be one
        }
    }; # audio {}

    for my $i ( 0 .. $#keys ) {
        my $ayah_key = $keys[ $i ];
        my $hash_ref = $list[ $i ];
           $hash_ref->{language} = $vars{language} if $vars{language};
    }

    return wantarray ? @list : \@list;
}

sub validate_shared {
    my ( $self, $vars ) = @_;

    return $self->render_error( type => 'validation', message => "neither 'quran' nor 'content' parameters are set; see /options/quran and /options/content for valid id values" )
    unless defined $vars->{quran}
        or defined $vars->{content};

    do {
        my $type = $_;
        my $val = $vars->{ $_ };
        return $self->render_error( type => 'validation', message => "invalid '$type' parameter; see /options/$type for valid 'id' values" )
            if defined $val and ( ref $val or not grep { $val eq $_ } map { $_->{id} } $self->_options->$type );
    } for qw/quran audio language/;

    if ( defined $vars->{content} ) {
        $vars->{content} = [ split /\W+/, $vars->{content} ] unless ref $vars->{content};
        return $self->render_error( type => 'validation', message => "invalid 'content' parameter (need a single integer id or an array of ids); see /options/content for valid 'id' values" )
        unless ref $vars->{content} eq 'ARRAY' and scalar @{ $vars->{content} };
        $vars->{content} = [ uniq @{ $vars->{content} } ];

        do {
            my $type = 'content';
            my $val = $_;
            return $self->render_error( type => 'validation', message => "invalid '$type' parameter; see /options/$type for valid 'id' values" )
                if defined $val and ( ref $val or not grep { $val eq $_ } map { $_->{id} } $self->_options->$type );
        } for @{ $vars->{content} };
    }
}

# ABSTRACT: DNR principle
1;
__END__

=head1 SYNOPSIS

=cut
