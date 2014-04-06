use Test::More;
use Test::Mojo;

use_ok 'QuranAPI';

my $t = Test::Mojo->new( 'QuranAPI' );

$t->get_ok( '/' )
    ->status_is( 200 );

done_testing();
