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

    $r->add_condition( _valid_ayat => sub {
        my ( $route, $c, $input, $validation ) = @_;
        my %args = $c->args;
        my %input = ( map { $_ => $input->{ $_ } } grep { defined $input->{ $_ } } keys %{ $input } );
           %input = ( %input, %args, %input ); # a bit of bloat that let's query-string and json vars override captures, e.g. /bucket/ayat/2?range=3-4 is the same as /bucket/ayat/2/3-4. useful for `POST /bucket/ayat => json => { surah => 2, range => [ 3, 4 ] }`

        $input->{ $_ } = $input{ $_ } for keys %input;
        $input->{surah} //= 0;

        $validation->input( $input );
        $validation->required( 'surah' )->in( 1..114 );
        return undef if $validation->has_error;

        $input = $validation->input;

        my $range = $c->db->query( qq|
            select min( ayah_num ) "min"
                 , max( ayah_num ) "max"
              from quran.ayah
             where surah_id = ?
        |, $input->{surah} )->hash; # TODO: db calls like this need to be cached

        $input->{range} //= [ $range->{min}, $range->{max} ]; # TODO: limits on max range if the calls take too long on 1..286 for example
        $input->{range} = [ $1, $2 ] if not ref $input->{range}
            and $input->{range} =~ qr/^(\d+)(?:\W+(\d+))?$/;

        $validation->required( 'range' );

        return undef
        unless ref $input->{range} eq 'ARRAY'
           and $input->{range}[0] >= $range->{min}
           and $input->{range}[0] <= $range->{max};
        $input->{range}[1] //= $input->{range}[0];
        return undef
        unless $input->{range}[1] >= $input->{range}[0]
           and $input->{range}[1] >= $range->{min}
           and $input->{range}[1] <= $range->{max};

        my $output = $validation->output;
        my $stash = $c->stash;
           $stash->{args}{ $_ } = $output->{ $_ } for keys %{ $output };
        return 1;
    } );

    $r->add_condition( _valid_page => sub {
        my ( $route, $c, $input, $validation ) = @_;
        my %args = $c->args;
        my %input = ( map { $_ => $input->{ $_ } } grep { defined $input->{ $_ } } keys %{ $input } );
           %input = ( %input, %args, %input ); # a bit of bloat that let's query-string and json vars override captures, e.g. /bucket/ayat/2?range=3-4 is the same as /bucket/ayat/2/3-4. useful for `POST /bucket/ayat => json => { surah => 2, range => [ 3, 4 ] }`

        $input->{ $_ } = $input{ $_ } for keys %input;
        $input->{page} //= 0;

        $validation->input( $input );
        $validation->required( 'page' )->in( 1..604 );
        return undef if $validation->has_error;

        my $output = $validation->output;
        my $stash = $c->stash;
           $stash->{args}{ $_ } = $output->{ $_ } for keys %{ $output };
        return 1;
    } );

    $r->any( '/bucket/ayat/:surah/:range' )->over( _valid_ayat => $self->validator->validation )->to( controller => 'Bucket::Ayat', action => 'list', surah => undef, range => undef );
    $r->any( '/bucket/page/:page' )->over( _valid_page => $self->validator->validation )->to( controller => 'Bucket::Page', action => 'list', page => undef );

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

    $self->secrets( [ $self->config->{application}{secret} ] );

    CORS: {
        $self->hook( before_dispatch => sub {
            my $c = shift;
            $c->res->headers->header( 'Access-Control-Allow-Origin' => '*' );
            $c->res->headers->header( 'Access-Control-Allow-Methods' => 'POST, GET, PUT, DELETE, OPTIONS' );
            $c->res->headers->header( 'Access-Control-Max-Age' => 3600 );
            $c->res->headers->header( 'Access-Control-Allow-Headers' => 'X-Requested-With' );
        } );
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
