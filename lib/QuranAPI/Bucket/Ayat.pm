package QuranAPI::Bucket::Ayat;
use Mojo::Base 'QuranAPI::Bucket';

sub list {
    my $self = shift;
    my ( $stash ) = ( $self->stash );
    my ( %args, %vars, %defs );
    my ( @keys, @list );

    %args = $self->args;

    %defs = $self->_options->default; # {"quran":211,"content":217,"language":"en","audio":6}
    $args{ $_ } //= $defs{ $_ } for qw/quran content audio language/; # TODO don't set defaults

    $vars{ $_ } = $args{ $_ } for grep { defined $args{ $_ } } qw/surah range quran content audio language/;

    validation: {
        $vars{surah} //= 1;

        return $self->render_error( type => 'validation', message => 'surah out of range' )
        unless defined $vars{surah}
           and $vars{surah} =~ qr/^\d+$/
           and $vars{surah} >= 1
           and $vars{surah} <= 114;

        my $max = $self->cache( join( '.', qw/max/, $vars{surah} ) => sub {
            return $self->db->query( qq|
                select max( ayah_num ) "max"
                  from quran.ayah
                 where surah_id = ?
            |, $vars{surah} )->list;
        } );

        $vars{range} //= [ 1, $max <= 1 + 50 ? $max : 1 + 50 ];
        $vars{range} = [ $1, $2 || $1 ] if not ref $vars{range} and $vars{range} =~ qr/^(\d+)(?:\W+(\d+))?$/;
        $vars{range}[1] = $max if ref $vars{range} eq 'ARRAY' and scalar @{ $vars{range} } eq 2 and defined $vars{range}[1] and $vars{range}[1] >= $max; # just so that we don't have range [ 252, 301 ] throwing an error

        return $self->render_error( type => 'validation', message => "range not set or invalid, use a string or an array (maximum 50 ayat per request), e.g. '1-3' or [ 1, 3 ]" )
        unless ref $vars{range} eq 'ARRAY'
           and scalar @{ $vars{range} } eq 2
           and $vars{range}[0] =~ qr/^\d+$/
           and $vars{range}[1] =~ qr/^\d+$/
           and $vars{range}[0] <= $vars{range}[1]
           and $vars{range}[0] >= 1
           and $vars{range}[1] >= 1
           and $vars{range}[0] <= $max
           and $vars{range}[1] <= $max
           and $vars{range}[1] - $vars{range}[0] <= 50;

        $self->validate_shared( \%vars );
    };

    @keys = $self->keys_for_ayat( surah => $vars{surah}, range => $vars{range} );
    @list = $self->bucket( keys => \@keys, vars => \%vars );

    $self->render( json => \@list );
}

# ABSTRACT: Pass in options hash, get the data returned for the specified surah and ayah range
1;
__END__

=head1 USAGE

here's a cheap jQuery example until code starts to mature (still very much a WIP):

    $.ajax( {
        url: 'http://api.v2.quran.com/bucket/ayat'
        ,type: 'OPTIONS'
        ,contentType: 'application/json'
        ,headers: { 'X-Requested-With': 'jQuery' }
        ,dataType: 'json'
        ,crossDomain: true
        ,data: JSON.stringify( { surah: 2, range: [1,4], audio: 5, content: [ 215 ], quran: 254 } )
    } ).done( function ( r ) {
        console.dir( r );
    } ).fail( function ( ) {
        console.debug( 'fail', arguments );
    } );

You can also try it via a GET to http://api.v2.quran.com/bucket/ayat/2/1-4?audio=5&content=215&quran=254

=cut
