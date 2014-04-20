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

=head1 USAGE

v2 quran api; documentation is very poor and pretty much non-existent atm. be patient.

=head2 /search

=head2 /bucket/ayat/:surah/:range

=head2 /bucket/page/:page

=head2 /options/default

=head2 /options/quran

=head2 /options/content

=head2 /options/language

=head2 /options/audio

=head2 /info/ayah

=head2 /info/page

=head2 /info/surah

=cut
