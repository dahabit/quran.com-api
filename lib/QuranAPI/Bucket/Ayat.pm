package QuranAPI::Bucket::Ayat;
use Mojo::Base 'QuranAPI::Bucket';

sub list {
    my $self = shift;
    my $stash = $self->stash;
    my %args = $self->args;
    my %default = %{ $self->defaults }; # {"quran":211,"content":217,"language":"en","audio":6}
    my $param; # TODO: handle param validation $self->app->validator;
    my %hash;
    my @list;

    # TODO: handle string or array on quran, content

    $param->{content} = $args{content} //= $default{content};

    my $res = $self->db->query( qq|
        select r.*
          from resource r
          join content.resource_api_version v using ( resource_id )
         where r.is_available
           and v.v2_is_enabled
           and r.type = 'content'
           and r.resource_id = ?
    |, $param->{content} )->hash;

    $self->render( json => {
        res => $res
        ,args => \%args
        ,param => $param
    } );
}

# ABSTRACT: Pass in options hash, get the data returned for the specified surah and ayah range
1;
__END__

=head1 USAGE

=cut
