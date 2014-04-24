use Test::More;
use Test::Most qw/bail/;
use Test::Mojo;

restore_fail;
use_ok 'QuranAPI';

my $t = new Test::Mojo ( 'QuranAPI' );

$t->get_ok( '/options/language' )
    ->status_is( 200 )
    ->json_has( '/0/id' );

$t->get_ok( '/options/audio' )
    ->status_is( 200 )
    ->json_has( '/0/id' );

$t->get_ok( '/options/content' )
    ->status_is( 200 )
    ->json_has( '/0/id' );

my $tx = $t->get_ok( '/options/quran' )
    ->status_is( 200 )
    ->json_has( '/0/id' )->tx;

bail_on_fail;
subtest '/options/quran: consistent data-structure' => sub {
    my %slug;
    can_ok $tx->res, 'json';
    isa_ok $tx->res->json, 'ARRAY';
    do {
        $slug{ $_->{slug} } = 1;
    } for @{ $tx->res->json };
    ok exists $slug{ $_ }
    , "encountered $_" for qw/
        ayah_image
        ayah_text_regular
        ayah_text_minimal
        word_font
        word_image_regular
        word_image_tajweed
    /;
};
restore_fail;

$t->get_ok( '/options/default' )
    ->status_is( 200 )
    ->json_has( '/audio' )
    ->json_has( '/quran' )
    ->json_has( '/content' )
    ->json_has( '/language' )
;

$t->get_ok( '/' )
    ->status_is( 302 );

done_testing;
