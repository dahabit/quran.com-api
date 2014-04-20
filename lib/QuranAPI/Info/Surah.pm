package QuranAPI::Info::Surah;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;
    my ( $stash, %args, %vars ) = ( $self->stash, $self->args );

    $vars{surah} = $args{surah}
        if defined $args{surah}
       and $args{surah} =~ qr/^\d+$/
       and $args{surah} >= 1
       and $args{surah} <= 114;

    my $list = $self->cache( join( '.', qw/info surah/, $vars{surah} || 'all' ) => sub {
        my @bind; push @bind, $vars{surah} if defined $vars{surah};
        my $list = $self->db->query( qq|
            select s.surah_id id
                 , s.ayat
                 , s.bismillah_pre
                 , s.revelation_order
                 , s.revelation_place
                 , s.page
                 , s.name_complex
                 , s.name_simple
                 , s.name_english
                 , s.name_arabic
              from quran.surah s |.( ( not $vars{surah} ) ? '' : 'where surah_id = ?' ).qq|
             order by s.surah_id
        |, @bind )->hashes;
        for my $item ( @{ $list } ) {
            my %mash;
               $mash{revelation} = [ qw/order place/ ];
               $mash{name}       = [ qw/complex simple english arabic/ ];
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
        return $list->[0] if defined $vars{surah};
        return $list;
    } );
    $self->render( json => $list );
}

# ABSTRACT: surah info
1;
