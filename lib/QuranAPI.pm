package QuranAPI;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;

    $self->setup;

    my $r = $self->routes;

    $r->get( '/options/language' )->to( controller => 'Options::Language', action => 'list' );
    $r->get( '/options/audio' )->to( controller => 'Options::Audio', action => 'list' );
    $r->get( '/options/quran' )->to( controller => 'Options::Quran', action => 'list' );
    $r->get( '/options/content' )->to( controller => 'Options::Content', action => 'list' );
    $r->get( '/options/default' )->to( controller => 'Options::Default', action => 'hash' );
    $r->get( '/bucket/ayat/:surah/:range' )->to( controller => 'Bucket::Ayat', action => 'list' );
    $r->get( '/bucket/page/:page' )->to( controller => 'Bucket::Page', action => 'list' );

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
