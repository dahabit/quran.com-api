package QuranAPI;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;

    $self->setup;

    my $r = $self->routes;

    options: {
        $r->get( '/options/default' )->to( cb => sub {
            my $c = shift; my %args = $c->args; $c->render( json => scalar $c->_options->default( %args ) );
        } );
        $r->get( '/options/language' )->to( cb => sub {
            my $c = shift; my %args = $c->args; $c->render( json => scalar $c->_options->language( %args ) );
        } );
        $r->get( '/options/quran' )->to( cb => sub {
            my $c = shift; my %args = $c->args; $c->render( json => scalar $c->_options->quran( %args ) );
        } );
        $r->get( '/options/content' )->to( cb => sub {
            my $c = shift; my %args = $c->args; $c->render( json => scalar $c->_options->content( %args ) );
        } );
        $r->get( '/options/audio' )->to( cb => sub {
            my $c = shift; my %args = $c->args; $c->render( json => scalar $c->_options->audio( %args ) );
        } );
    };

    $r->get( '/content/tafsir/:tafsir_id' )->to( controller => 'Content::Tafsir', action => 'hash' );

    $r->get( $_ )->to( controller => 'Info::Surah', action => 'list' )
        for qw|/info/surah/:surah /info/surah|;

    $r->any( $_ )->to( controller => 'Bucket::Ayat', action => 'list' )
        for qw|/bucket/ayat/:surah/:range /bucket/ayat/:surah /bucket/ayat|;

    $r->any( $_ )->to( controller => 'Bucket::Page', action => 'list' )
        for qw|/bucket/page/:page /bucket/page|;

    $self->documentation( -root => '/docs' );
    $r->any( '/' )->to( cb => sub {
        my $c = shift;
        $c->redirect_to( $self->url_for( 'documentation' ) );
    } );
}

sub setup {
    my $self = shift;

    $self->plugin( 'Mojolicious::Plugin::Nour::Config', {
        -base => 'config'
        , -helpers => 1
        , -silence => 1
    } );
    $self->plugin( 'Mojolicious::Plugin::Nour::Database' );
    $self->plugin( 'Mojolicious::Plugin::Documentation' );
    $self->plugin( 'Mojolicious::Plugin::DumpyLog' );
    $self->plugin( 'Mojolicious::Plugin::CacheMoney' );
    $self->plugin( 'Mojolicious::Plugin::Args' );
    $self->plugin( 'Mojolicious::Plugin::UTF8' );
    $self->plugin( 'Mojolicious::Plugin::CORS' );

    $self->plugin( 'QuranAPI::Options' );

    render_error: {
        $self->helper( render_error => sub {
            my $c = shift;
            my %error = @_;
            my %param = map { $_ => delete $error{ $_ } } grep { defined $error{ $_ } } qw/code/;
            do {
                $param{code} = 422 if $error{type} eq 'validation';
            } if $error{type};
            $param{code} //= 500;
            $c->stash->{render_error} = 1;
            $c->res->code( $param{code} ) if $param{code};
            return $c->render( json => { error => \%error } ) && die;
        } );

        $self->hook( around_dispatch => sub {
            my ( $next, $c ) = @_;
            local $SIG{__DIE__} = sub { ref $_[0] ? CORE::die( $_[0] ) : Mojo::Exception->throw( @_ ) };
            do { # handle exception here
                return if $c->stash->{render_error}; die $@;
            } unless eval { $next->(); 1 }
        } );
    };

    $self->secrets( [ $self->config->{application}{secret} ] );

    setup_assurance: {
        my $mode = $self->mode;
        my $name = $self->db->query( qq|select current_database()| )->list;
        $self->info( "using $name" );
        $self->info( "under $mode" );
        $self->info( "config", scalar $self->config );
    };
}

# ABSTRACT: Quran API v2
1;
__END__

=encoding utf8

=head1 Usage

v2 quran api; documentation is very poor and pretty much non-existent atm. be patient.

=head1 Endpoints

=head2 using C</bucket> endpoints

All C</bucket> endpoints take two kinds of parameters: a) specific and b) generic. The second kind, "generic"
parameters, can get passed to any C</bucket> endpoint via either the query-string C<?quran=210&content=217,218>
or ajax/post data, e.g.

    jQuery.ajax( {
        url: 'http://api.v2.quran.com/bucket/page/1'
        ,type: 'POST'
        ,data: JSON.stringify( { quran: 210, content: [ 217, 218 ] } )
        ,dataType: 'json'
        ,contentType: 'application/json'
        ,crossDomain: true
        ,headers: { 'X-Requested-With': 'jQuery' }
    } ).done( function ( r ) {
        console.dir( r );
    } ).fail( function ( ) {
        console.debug( 'fail', arguments );
    } );

Generic parameters include C<quran>, C<content>, C<audio> and C<language>. Valid values for each of these four
types can be retrieved from their respective C</options> endpoint. For example, set the C<audio> parameter to correspond to
the C<id> of any option at C<L</options/audio|http://api.v2.quran.com/options/audio>>. The only generic parameter which
allows (and encourages) an array is C<content>. This is so that you can pull multiple translations (or transliterations or tafsir) at the same time.

Specific parameters pertain and differ for each specific bucket endpoint and can be set via the route itself
e.g. C</bucket/ayat/2/1-5> or via the query string, e.g. C</bucket/ayat?surah=2&range=1-5> or via ajax/post data.
For example, the specific parameters on C</bucket/ayat> are C<surah> and C<range>, e.g.

    jQuery.ajax( {
        url: 'http://api.v2.quran.com/bucket/ayat'
        ,type: 'POST'
        ,data: JSON.stringify( { surah: 2, range: [1, 5], quran: 210 } )
        ,dataType: 'json'
        ,contentType: 'application/json'
        ,crossDomain: true
        ,headers: { 'X-Requested-With': 'jQuery' }
    } ).done( function ( r ) {
        console.dir( r );
    } ).fail( function ( ) {
        console.debug( 'fail', arguments );
    } );


=head2 /bucket/ayat

L<QuranAPI::Bucket::Ayat>

=head2 /bucket/page

L<QuranAPI::Bucket::Page>

=head2 /options/default

Returns an options hash of suggested defaults to pass into any C</bucket/*> endpoint or the C</search> endpoint.
Passing in these options in alongside any endpoint-specific parameters to one of the afore-mentioned endpoints
will return an array of similarly keyed hashes; e.g. if you pass in

    {
        language: 'en'
        ,quran: 210
        ,content: 217
        ,audio: 1
    }

to C</bucket/page/1>, you'll get an array of ayat that resemble:

    [ {
        surah: 1
        ,ayah: 1
        ,language: 'en'
        ,quran: ...
        ,content: ...
        ,audio: ...
    }, { surah: 1, ayah: 2, ... }, { ... }, { ... }, { ... }, { ... }, { ... } ]


=head2 /options/quran

=head2 /options/content

=head2 /options/language

=head2 /options/audio

=head2 /info/surah

=head2 /content/tafsir

=head1 TODO

=head2 /info/ayah

=head2 /info/page

=head2 /search

=cut
