package QuranAPI::Bucket::Ayat;
use Mojo::Base 'QuranAPI::Bucket';

sub list {
    my $self = shift;
    my ( $stash ) = ( $self->stash );
    my ( %args, %defs, %vars ); # TODO: validate %args and put output in %vars ( $self->app->validator )
    my ( @keys, @list );

    %args = $self->args;
    %defs = $self->_options->default; # {"quran":211,"content":217,"language":"en","audio":6}

    $vars{ $_ } = $args{ $_ } for qw/surah range/;
    $vars{ $_ } = $args{ $_ } || $defs{ $_ } for qw/quran content audio language/; # setting it to defaults is temporary for experimenting--TODO validation, and TODO handle string or array on quran, content

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
        ,type: 'POST'
        ,contentType: 'application/json'
        ,dataType: 'json'
        ,crossDomain: true
        ,data: JSON.stringify( { surah: 2, range: [1,4], audio: 5, content: [ 215 ], quran: 254 } )
    } ).done( function ( r ) {
        c.dir( r );
    } );

You can also try it via a GET to http://api.v2.quran.com/bucket/ayat/2/1-4?audio=5&content=215&quran=254

=cut
