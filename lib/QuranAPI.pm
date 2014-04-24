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

    $r->any( '/' )->to( controller => 'Documentation', action => 'index', template => 'index' );
}

sub setup {
    my $self = shift;

    $self->plugin( 'Mojolicious::Plugin::Nour::Config', {
        -base => 'config'
        , -helpers => 1
        , -silence => 1
    } );
    $self->plugin( 'Mojolicious::Plugin::Nour::Database' );
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

    documentation: {
        push @{ $self->renderer->paths }, $self->path( qw/documentation template/ );
        push @{ $self->static->paths },   $self->path( qw/documentation public/ );
    };

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

=head2 using C</bucket/*> and C</search> endpoints

C</bucket/*> and C</search> endpoints take two kinds of parameters: a) shared parameters and b) route parameters.
Shared parameters are  C<quran>, C<content>, C<audio> and C<language> and 
can be passed to any C</bucket/*> or C</search> endpoint.
These parameters are described via C</options/*>, e.g.
C<audio> options are described at C<L</options/audio|http://api.v2.quran.com/options/audio>> and
the C<id> property from one of these objects constitutes a valid value for this parameter.
Set these via the query-string, e.g. C<?quran=210&content=217,218> or ajax/post data, e.g.

    jQuery.ajax( {
        url: 'http://api.v2.quran.com/bucket/page/1'
        ,type: 'POST'
        ,data: JSON.stringify( { quran: 210, content: [ 217, 218 ] } ) // via ajax data
        ,dataType: 'json'
        ,contentType: 'application/json'
        ,crossDomain: true
        ,headers: { 'X-Requested-With': 'jQuery' }
    } ).done( function ( r ) {
        console.dir( r );
    } ).fail( function ( ) {
        console.debug( 'fail', arguments );
    } );

The only shared parameter which permits multiple selections (via an array) is the C<content> parameter.
This is so that you can pull multiple translations (or transliterations or tafsir) at the same time.

Route parameters are relevant only to the endpoint itself.
For example, on C</bucket/ayat> route parameters are C<surah> and C<range>, making the accessible route C</button/ayat/:surah/:range>,
and on C</bucket/page> the route parameter is C<page>, thus the accessible route is C</bucket/page/:page>.
See L<the next section|http://api.v2.quran.com/docs#/bucket/ayat> for an example of route parameters.

B<I<note>> that C</search> has not been implemented yet. 

=head2 /bucket/ayat

=over 4

=item B<examples>

=over 4

=item C</bucket/ayat> I<surah 1, range 1..7>

=item C</bucket/ayat/1> I<surah 1, range 1..7>

=item C</bucket/ayat/2> I<surah 2, range 1..50 (B<50 ayat is the maximum range width>)>

=item C</bucket/ayat/2/51-100> I<surah 2, range 51..100>

=item C</bucket/ayat/2/251-300> I<surah 2, range 251..B<286>>

=item C</bucket/ayat/2/255> I<surah 2, ayah 255>

=item ...etc

=back

=back

Route parameters are set via the url, e.g. C</bucket/ayat/2/1-5>, or via the query string, e.g. C</bucket/ayat?surah=2&range=1-5>, or via ajax/post data, e.g.

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

=head2 /bucket/page

Takes the same shared parameters as C</bucket/ayat> (i.e. C<id> values from the C</options/*> endpoints), but returns ayat by page (range).

=over 4

=item B<examples>

=over 4

=item I<load page 293:>

    jQuery.ajax( {
        url: 'http://api.v2.quran.com/bucket/page/293'
        ,type: 'POST'
        ,data: JSON.stringify( { quran: 254 } )
        ,dataType: 'json'
        ,contentType: 'application/json'
        ,crossDomain: true
        ,headers: { 'X-Requested-With': 'jQuery' }
    } ).done( function ( r ) {
        console.dir( r );
    } ).fail( function ( ) {
        console.debug( 'fail', arguments );
    } );

=item I<load page 291 to 295 (B<5 pages is the maximum width>):>

    jQuery.ajax( {
        url: 'http://api.v2.quran.com/bucket/page/291-295'
        ,type: 'POST'
        ,data: JSON.stringify( { quran: 210 } )
        ,dataType: 'json'
        ,contentType: 'application/json'
        ,crossDomain: true
        ,headers: { 'X-Requested-With': 'jQuery' }
    } ).done( function ( r ) {
        console.dir( r );
    } ).fail( function ( ) {
        console.debug( 'fail', arguments );
    } );


=back

=back

=head2 /options/default

Returns an options hash of suggested defaults to pass into any C</bucket/*> endpoint or the C</search> endpoint.
Passing in these parameters instructs the endpoint to fetch the specified resource(s) for each ayah in range. The result is an array of hashes, keyed similarly but valued with the resource content.
For example, if you pass in

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

=over 4

=item B<I<TODO>>

=over 4

=item describe the C<type> property

=over 4

=item describe C<type B<image>>

=item describe C<type B<text>>

=item describe C<type B<font>>

=back

=item describe the C<slug> property

=over 4

=item describe C<slug B<word_font>>

=item describe C<slug B<ayah_image>>

=item describe C<slug B<ayah_text_regular>>

=item describe C<slug B<ayah_text_minimal>>

=item describe C<slug B<word_image_tajweed>> - I<currently unavailable>

=item describe C<slug B<word_image_regular>> - I<currently unavailable>

=back


=item describe the C<is_available> property

=item describe the C<cardinality> property and how it affects the resource data structure

=over 4

=item describe C<cardinality B<1_ayah>>

=item describe C<cardinality B<1_word>>

=item describe C<cardinality B<n_ayah>>

=back

=back

=back

=head2 /options/content

similar to C</options/quran>

=head2 /options/language

=over 4

=item B<I<TODO>>

=over 4

=item describe how this affects C<quran> options with C<1_word cardinality>.

=back

=back

=head2 /options/audio

straightforward

=head2 /info/surah

straightforward - C</info/surah> or C</info/surah/:surah> routes work (former lists all surah objects in an array, latter returns a single hash)

=head2 /content/tafsir

=over 4

=item B<I<TODO>>

=over 4

=item explain this!

=back

=back

=head1 B<TODO> B<I<not yet developed>>

=head2 /info/ayah

=head2 /info/page

=head2 /search

=cut
