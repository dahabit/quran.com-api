package QuranAPI::Options::Content;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;
    my $list = $self->db->query( qq|
        select r.resource_id id
             , r.sub_type "type"
             , r.cardinality_type cardinality
             , r.language_code "language"
             , r.slug
             , r.is_available
             , r.description
             , r.name
          from content.resource r
          join content.resource_api_version v using ( resource_id )
         where r.type = 'content'
           and v.v2_is_enabled
         order by r.resource_id
    | )->hashes;
    $self->render( json => $list );
}

1;
