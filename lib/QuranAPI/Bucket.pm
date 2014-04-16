package QuranAPI::Bucket;
use Mojo::Base 'QuranAPI::Options::Default';
sub keys_for_ayat {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );

    my @keys = $self->db->query( qq|
        select a.ayah_key
          from quran.ayah a
         where a.surah_id = ?
           and a.ayah_num >= ?
           and a.ayah_num <= ?
         order by a.surah_id, a.ayah_num
    |, $args{surah}, $args{range}[0], $args{range}[1] )->flat;

    return wantarray ? @keys : \@keys;
}

sub keys_for_page {
    my $self = shift;
    my ( $stash, %args ) = ( $self->stash, @_ );
}

# ABSTRACT: DNR principle
1;
__END__

=head1 SYNOPSIS

=cut
