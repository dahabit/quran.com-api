package QuranAPI;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;

    $self->setup;

    my $r = $self->routes;

    $r->get( '/options/languages' )->to( controller => 'Options::Languages', action => 'list' );
    $r->get( '/options/audio' )->to( controller => 'Options::Audio', action => 'list' );
    $r->get( '/options/quran' )->to( controller => 'Options::Quran', action => 'list' );
    $r->get( '/options/content' )->to( controller => 'Options::Content', action => 'list' );

    $self->documentation( -root => '/docs' );
    $r->any( '/' )->to( cb => sub {
        my $c = shift;
        $c->redirect_to( $self->url_for( 'documentation' ) );
    } );
}

sub setup {
    my $self = shift;

    $self->plugin( 'Mojolicious::Plugin::DumpyLog' );
    $self->plugin( 'Mojolicious::Plugin::Args' );
    $self->plugin( 'Mojolicious::Plugin::Nour::Config', {
        -base => 'config'
        , -helpers => 1
        , -silence => 1
    } );
    $self->plugin( 'Mojolicious::Plugin::Nour::Database' );
    $self->plugin( 'Mojolicious::Plugin::Documentation' );

    $self->secrets( [ $self->config->{application}{secret} ] );

    setup_assurance: {
        my $mode = $self->mode;
        my $name = $self->db->query( qq|select current_database()| )->list;
        $self->debug( "using $name" );
        $self->debug( "under $mode" );
        $self->debug( "config", scalar $self->config );
    };
}

1;

# ABSTRACT: v2 quran api

=encoding utf8

=head1 QuranAPI

=head2 /options

=head3 /options/languages

foo

=cut
