package QuranAPI;
use Mojo::Base 'Mojolicious';
use Nour::Database; has '_nour_db';

sub startup {
    my $self = shift;

    $self->setup;

    my $r = $self->routes;

    $r->get( '/' )->to( 'documentation#index' );

    $r->get( '/options/languages' )->to( controller => 'Options::Languages', action => 'list' );
}

sub setup {
    my $self = shift;
    logger_methods: {
        do { my $method = $_;
        $self->helper( $method => sub {
            my ( $c, @args ) = @_;

            my $dump = pop @args if ref $args[ -1 ];
            my $name = ref $c eq 'Mojolicious::Controller' ? ref $c->app : ref $c;

            $c->app->log->$method( $name .' - '. join ', ', grep { defined } @args );
            $c->app->log->$method( $c->dumper( $dump ) ) if $dump;
        } ) } for qw/debug error fatal info log warn/; # proxy over the base logger methods
    };

    $self->plugin( 'Mojolicious::Plugin::YAMLConfig', {
        -base => 'config'
        , include_extra => 1
    } );

    $self->secrets( [ $self->config->{application}{secret} ] );

    database_setup: {
        $self->helper( _connect_db => sub {
            my ( $c, @args ) = @_; $self->debug( '_connect_db' );
            my $mode = $self->mode;
            my $conf = $self->config( 'database' );
            $conf->{default}{database} = $mode if exists $conf->{ $mode }; # we'll set the default db to "development" if we're in development mode
            $self->_nour_db( new Nour::Database ( %{ $conf } ) );
        } );
        $self->helper( db => sub {
            my ( $c, @args ) = @_;
            $self->_connect_db unless $self->_nour_db;
            return $self->_nour_db->switch_to( @args ) if @args;
            return $self->_nour_db;
        } );
        $self->hook( before_dispatch => sub {
            my ( $c, @args ) = @_;
            $self->_connect_db unless $self->db->dbh->ping;
        } );
    };

    my $mode = $self->mode;
    my $name = $self->db->query( qq|select current_database()| )->list;
    $self->debug( "using $name" );
    $self->debug( "under $mode" );
    $self->debug( 'config', scalar $self->config );
}

1;

# ABSTRACT: v2 quran api

=encoding utf8

=head1 QuranAPI

=head2 /options

=head3 /options/languages

=cut
