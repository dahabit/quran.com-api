use Test::More tests => 2;

BEGIN { use_ok( 'QuranAPI' ); }

my $object = QuranAPI->new ();
isa_ok ($object, 'QuranAPI');
