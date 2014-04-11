package QuranAPI;
use Mojo::Base 'Mojolicious';
use Nour::Database; has '_nour_db';

sub startup {
    my $self = shift;

    $self->setup;

    my $r = $self->routes;

    $r->get( '/' )->to( 'documentation#index' );

    $r->get( '/options/languages' )->to( controller => 'Options::Languages', action => 'list' );
    $r->get( '/options/audio' )->to( controller => 'Options::Audio', action => 'list' );
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

    $self->plugin( 'Mojolicious::Plugin::Nour::Config', {
        -base => 'config'
        , -helpers => 1
    } );

    $self->secrets( [ $self->config->{application}{secret} ] );

    $self->plugin( 'Mojolicious::Plugin::Nour::Database' );

    my $mode = $self->mode;
    my $name = $self->db->query( qq|select current_database()| )->list;
    $self->debug( "using $name" );
    $self->debug( "under $mode" );
}

1;

# ABSTRACT: v2 quran api

=encoding utf8

=head1 QuranAPI

=head2 /options

=head3 /options/languages

=cut
