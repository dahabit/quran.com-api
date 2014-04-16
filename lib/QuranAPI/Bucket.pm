package QuranAPI::Bucket;
use Mojo::Base 'QuranAPI::Options::Default';
use List::AllUtils qw/uniq/;

sub keys_for_ayat {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );

    my @keys = $self->db->query( qq|
        select a.ayah_key
          from quran.ayah a
         where a.surah_id = ?
           and a.ayah_num >= ?
           and a.ayah_num <= ?
         order by a.surah_id, a.ayah_num
    |, $args{surah}, $args{range}[0], $args{range}[1] )->flat;

    return wantarray ? @keys : \@keys;
}

sub keys_for_page {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );

    my @keys = $self->db->query( qq|
        select a.ayah_key
          from quran.ayah a
         where a.page_num = ?
         order by a.surah_id, a.ayah_num
    |, $args{page} )->flat;

    return wantarray ? @keys : \@keys;
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
        $hash{language} = $vars{language};
        $hash{audio} = 'TODO';
        push @list, \%hash;
    }

    quran: { next unless defined $vars{quran};
        $rows{ 'resource.quran' } = $self->db->query( qq|
            select r.*
              from content.resource r
              join content.resource_api_version v using ( resource_id )
             where r.is_available
               and v.v2_is_enabled
               and r.type = 'quran'
               and r.resource_id in ( ? )
        |, $vars{quran} )->hash;

        if ( my $row = $rows{ 'resource.quran' } ) {
            my $join;
            if ( $row->{cardinality_type} eq '1_word' ) {
                $join = "join $row->{type}.$row->{slug} c using ( resource_id )";
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
                $join = "join $row->{type}.$row->{sub_type} c using ( resource_id )";
            }

            if ( $row->{cardinality_type} eq '1_word' ) { # TODO
                $rows{ 'result.quran' } = $self->cache( join( '', '1_word', $vars{language}, $row->{resource_id}, @keys ) => sub {
                    my %rows;
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
                           $mash_key{image} = [ qw/id bloo blee blah/ ];

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
                        push @{ $rows{ $ayah_key } }, $result;
                    }
                    return \%rows;
                } );

                for my $i ( 0 .. $#keys ) {
                    my $ayah_key = $keys[ $i ];
                    my $hash_ref = $list[ $i ];
                    for my $result ( @{ $rows{ 'result.quran' }{ $ayah_key } } ) {
                        push @{ $hash_ref->{quran} }, $result;
                    }
                }
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
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
                    $rows{ 'result.quran' }{ $ayah_key } = $result;
                }
                for my $i ( 0 .. $#keys ) {
                    my $ayah_key = $keys[ $i ];
                    my $hash_ref = $list[ $i ];
                    if ( my $result = $rows{ 'result.quran' }{ $ayah_key } ) {
                        $hash_ref->{quran} = $result;
                    }
                }
            }
        }
    }; # quran {}

    content: { next unless defined $vars{content};
        $vars{content} = [ $vars{content} ] unless ref $vars{content};
        $vars{content} = [ uniq @{ $vars{content} } ];

        $rows{ 'resource.content' } = $self->db->query( qq|
            select r.*
              from content.resource r
              join content.resource_api_version v using ( resource_id )
             where r.is_available
               and v.v2_is_enabled
               and r.type = 'content'
               and r.resource_id in ( |.( join ', ', map { '?' } @{ $vars{content} } ).qq| )
             order by ( |.( join ', ', map { 'r.resource_id = ?' } @{ $vars{content} } ).qq| ) desc
        |, ( @{ $vars{content} }, @{ $vars{content} } ) )->hashes;

        for my $row ( @{ $rows{ 'resource.content' } } ) {
            my $join;
               if ( $row->{cardinality_type} eq 'n_ayah' ) {
                $join = "join $row->{type}.$row->{sub_type} c using ( resource_id ) join $row->{type}.$row->{sub_type}_ayah n using ( $row->{sub_type}_id )";
            }
            elsif ( $row->{cardinality_type} eq '1_word' ) {
                $join = "join $row->{type}.$row->{slug} c using ( resource_id )";
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
                $join = "join $row->{type}.$row->{sub_type} c using ( resource_id )";
            }

               if ( $row->{cardinality_type} eq 'n_ayah' ) { # TODO
            }
            elsif ( $row->{cardinality_type} eq '1_word' ) { # TODO
            }
            elsif ( $row->{cardinality_type} eq '1_ayah' ) {
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
                    push @{ $rows{ 'result.content' }{ $ayah_key } }, $result;
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

    return wantarray ? @list : \@list;
};

# ABSTRACT: DNR principle
1;
__END__

=head1 SYNOPSIS

=cut
