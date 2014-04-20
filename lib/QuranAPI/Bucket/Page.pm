package QuranAPI::Bucket::Page;
use Mojo::Base 'QuranAPI::Bucket';

sub list {
    my $self = shift;
    my ( $stash ) = ( $self->stash );
    my ( %args, %vars, %defs );
    my ( @keys, @list );

    %args = $self->args;

    %defs = $self->_options->default; # {"quran":211,"content":217,"language":"en","audio":6}
    $args{ $_ } //= $defs{ $_ } for qw/quran content audio language/; # TODO don't set defaults

    $vars{ $_ } = $args{ $_ } for grep { defined $args{ $_ } } qw/page quran content audio language/;

    validation: {
        $vars{page} //= [ 1, 1 ];
        $vars{page} = [ $1, $2 || $1 ] if not ref $vars{page} and $vars{page} =~ qr/^(\d+)(?:\W+(\d+))?$/;

        return $self->render_error( type => 'validation', message => "page not set or invalid, use an integer or a range (string or array, maximum 5 pages per request), e.g. '1-3' or [ 1, 3 ]" )
        unless ref $vars{page} eq 'ARRAY'
           and scalar @{ $vars{page} } eq 2
           and $vars{page}[0] =~ qr/^\d+$/
           and $vars{page}[1] =~ qr/^\d+$/
           and $vars{page}[0] <= $vars{page}[1]
           and $vars{page}[0] >= 1
           and $vars{page}[1] >= 1
           and $vars{page}[0] <= 604
           and $vars{page}[1] <= 604
           and $vars{page}[1] - $vars{page}[0] <= 5;

        $self->validate_shared( \%vars );
    };

    @keys = $self->keys_for_page( page => $vars{page} );
    @list = $self->bucket( keys => \@keys, vars => \%vars );

    $self->render( json => \@list );
}

# ABSTRACT: Pass in options hash, get the data returned for the specified page
1;
__END__

=head1 USAGE

here's a cheap jQuery example until code starts to mature (still very much a WIP):

    $.ajax( {
        url: 'http://api.v2.quran.com/bucket/page'
        ,type: 'POST'
        ,contentType: 'application/json'
        ,dataType: 'json'
        ,crossDomain: true
        ,data: JSON.stringify( { page: 293, audio: 5, content: [ 215, 217, 216 ], quran: 254 } )
    } ).done( function ( r ) {
        console.dir( r );
    } );

You can also try it via a GET to http://api.v2.quran.com/bucket/page/293?audio=5&content=215&quran=254

=cut
