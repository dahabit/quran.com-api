use Test::More;
use Test::Mojo;

use_ok 'QuranAPI';

my $t = Test::Mojo->new( 'QuranAPI' );

$t->get_ok( '/' )
    ->status_is( 200 );

$t->get_ok( '/options/languages' )
    ->status_is( 200 )
    ->json_has( '/0/id' );

$t->get_ok( '/options/audio' )
    ->status_is( 200 )
    ->json_has( '/0/id' );

$t->get_ok( '/options/content' )
    ->status_is( 200 )
    ->json_has( '/0/id' );

$t->get_ok( '/options/quran' )
    ->status_is( 200 )
    ->json_has( '/0/id' );

done_testing();
