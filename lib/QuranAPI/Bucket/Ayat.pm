package QuranAPI::Bucket::Ayat;
use Mojo::Base 'QuranAPI::Bucket';
use List::AllUtils qw/uniq/;
use Tie::IxHash;

sub list {
    my $self = shift;
    my ( $stash ) = ( $self->stash );
    my ( %args, %defs, %vars, %rows ); # TODO: validate %args and put output in %vars ( $self->app->validator )
    my ( @keys, @list );

    %args = $self->args;
    %defs = $self->defaults; # {"quran":211,"content":217,"language":"en","audio":6}

    $vars{ $_ } = $args{ $_ } for qw/surah range/;
    $vars{ $_ } = $args{ $_ } || $defs{ $_ } for qw/quran content audio/; # setting it to defaults is temporary for experimenting--TODO validation, and TODO handle string or array on quran, content

    @keys = $self->keys_for_ayat( surah => $vars{surah}, range => $vars{range} );
    for my $ayah_key ( @keys ) {
        my ( $surah, $ayah ) = split /:/, $ayah_key;
        my ( $tie, %hash );
        $tie = tie %hash, 'Tie::IxHash';
        $hash{surah} = $surah;
        $hash{ayah} = $ayah;
        $hash{tie} = $tie;
        push @list, \%hash;
    }

    content: { next unless defined $vars{content};
        $vars{content} = [ $vars{content} ] unless ref $vars{content};
        $vars{content} = [ uniq @{ $vars{content} } ];

        $rows{ 'content.resource' } = $self->db->query( qq|
            select r.*
              from content.resource r
              join content.resource_api_version v using ( resource_id )
             where r.is_available
               and v.v2_is_enabled
               and r.type = 'content'
               and r.resource_id in ( |.( join ', ', map { '?' } @{ $vars{content} } ).qq| )
             order by ( |.( join ', ', map { 'r.resource_id = ?' } @{ $vars{content} } ).qq| ) desc
        |, ( @{ $vars{content} }, @{ $vars{content} } ) )->hashes;

        for my $row ( @{ $rows{ 'content.resource' } } ) {
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
                my @content = $self->db->query( qq|
                    select c.*
                      from content.resource r $join
                      join quran.ayah a using ( ayah_key )
                     where r.resource_id = ?
                       and a.ayah_key in ( |.( join ', ', map { '?' } @keys ).qq| )
                     order by a.surah_id, a.ayah_num
                |, $row->{resource_id}, @keys )->hashes;
                for my $result ( @content ) {
                    my $resource_id = delete $result->{resource_id};
                    my $ayah_key    = delete $result->{ayah_key};
                    push @{ $rows{content}{ $ayah_key } }, $result;
                }
            }
        }

        for my $i ( 0 .. $#keys ) {
            my $ayah_key = $keys[ $i ];
            my $hash_ref = $list[ $i ];
            for my $result ( @{ $rows{content}{ $ayah_key } } ) {
                push @{ $hash_ref->{content} }, $result;
            }
        }
    }; # content block

    ordered_hash: {
        for my $i ( 0 .. $#keys ) {
            my $ayah_key = $keys[ $i ];
            my $hash_ref = $list[ $i ];
            my $hash_tie = delete $hash_ref->{tie};
               $hash_tie->Reorder( qw/surah ayah quran content audio/ );
        }
    }; # ordered_hash


# if 1_word => use type.slug, if 1_ayah => use type.sub_type, if n_ayah => use type.sub_type join type.sub_type_ayah
    $self->render( json => {
        rows => \%rows
        ,args => \%args
        ,defs => \%defs
        ,vars => \%vars
        ,keys => \@keys
        ,list => \@list
    } );
}

# ABSTRACT: Pass in options hash, get the data returned for the specified surah and ayah range
1;
__END__

=head1 USAGE

=cut
