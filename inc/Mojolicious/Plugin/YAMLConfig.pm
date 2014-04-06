package Mojolicious::Plugin::YAMLConfig;
use Mojo::Base 'Mojolicious::Plugin';
use Nour::Config;

has 'nour_config';

sub register {
    my ( $self, $app, $opts ) = @_;
    my $include_extra = delete $opts->{include_extra};

    $self->nour_config( new Nour::Config ( %{ $opts } ) );

    if ( $include_extra ) { # inherit some helpers from Nour::Base
        do { my $method = $_; eval qq|
        \$app->helper( $method => sub {
            my ( \$ctrl, \@args ) = \@_;
            return \$self->nour_config->$method( \@args );
        } )| } for qw/path merge_hash write_yaml/;
    }

    my $config = $self->nour_config->config;
    my $current = $app->defaults( config => $app->config )->config;
    %{ $current } = ( %{ $current }, %{ $config } );

    return $current;
}

1;

# ABSTRACT: imports config from a ./config directory full of nested yaml goodness
