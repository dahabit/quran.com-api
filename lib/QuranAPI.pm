package QuranAPI;
use Mojo::Base 'Mojolicious';

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

    $self->plugin( 'Mojolicious::Plugin::DumpyLog' );
    $self->plugin( 'Mojolicious::Plugin::Args' );
    $self->plugin( 'Mojolicious::Plugin::Nour::Config', {
        -base => 'config'
        , -helpers => 1
        , -silence => 1
    } );
    $self->plugin( 'Mojolicious::Plugin::Nour::Database' );

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

=cut
