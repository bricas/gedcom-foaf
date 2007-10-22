use inc::Module::Install 0.67;

if( -e 'MANIFEST.SKIP' ) {
    system( 'pod2text lib/Gedcom/FOAF.pm > README' );
}

name 'Gedcom-FOAF';
all_from 'lib/Gedcom/FOAF.pm';

requires 'Gedcom';
requires 'XML::LibXML';

requires 'Test::More';

auto_install;
WriteAll;
