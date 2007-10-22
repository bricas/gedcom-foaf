package Gedcom::FOAF;

=head1 NAME

Gedcom::FOAF - Output FOAF files from Gedcom individuals and families

=head1 SYNOPSIS

    use Gedcom;
    use Gedcom::FOAF;
    
    my $gedcom = Gedcom->new( gedcom_file => 'myfamily.ged' );
    my $i = $gedcom->get_individual( 'Butch Cassidy' );
    
    # print the individual's FOAF
    print $i->as_foaf;
    
    my( $f ) = $i->famc;
    
    # print the individual's family's (as a child) FOAF
    print $f->as_foaf;

=head1 DESCRIPTION

This module provides C<as_foaf> methods to individual and family
records. The resulting files can be parsed and crawled (scuttered)
by any code that understands the FOAF and RDF specs.

=head1 METHODS

=cut

use strict;
use warnings;

use XML::LibXML;

our $VERSION = '0.03';

my %namespaces = (
    rdf  => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    rdfs => 'http://www.w3.org/2000/01/rdf-schema#',
    rel  => 'http://purl.org/vocab/relationship/',
    foaf => 'http://xmlns.com/foaf/0.1/',
    bio  => 'http://purl.org/vocab/bio/0.1/'
);

package Gedcom::Individual;

=head2 Gedcom::Individual

=head3 as_foaf( $baseurl )

Generates a FOAF (XML) string from the Gedcom::Individual object. Pass
in a base url if desired.

=cut

sub as_foaf {
    my $self    = shift;
    my $baseurl = shift || '';
    my $xml     = XML::LibXML::Document->new( '1.0', 'UTF8' );

    my $rdf = $xml->createElement( 'RDF' );

    $rdf->setNamespace( $namespaces{ rdf },  'rdf' );
    $rdf->setNamespace( $namespaces{ rdfs }, 'rdfs', 0 );
    $rdf->setNamespace( $namespaces{ rel },  'rel', 0 );
    $rdf->setNamespace( $namespaces{ foaf }, 'foaf', 0 );
    $rdf->setNamespace( $namespaces{ bio },  'bio', 0 );

    $xml->setDocumentElement( $rdf );

    for ( $self->famc, $self->fams ) {
        $rdf->appendChild( $_->_foaf_seealso( $self, $baseurl ) );
    }

    my $xref    = $self->xref;
    my $url     = "$baseurl$xref.xml";
    my $urlspec = "$url#$xref";

    my $person = $xml->createElement( 'foaf:Person' );
    $person->setAttribute( 'rdf:about' => $urlspec );

    my $name = $xml->createElement( 'foaf:name' );
    $name->appendText( $self->label_name );

    my $firstname = $xml->createElement( 'foaf:givenname' );
    $firstname->appendText( $self->given_names );

    my $lastname = $xml->createElement( 'foaf:family_name' );
    $lastname->appendText( $self->surname );

    $person->appendChild( $name );
    $person->appendChild( $firstname );
    $person->appendChild( $lastname );

    for my $photo ( $self->tag_value( 'PHOT' ) ) {
        my $depic = $xml->createElement( 'foaf:depiction' );
        $depic->setAttribute(
            'rdf:resource' => $baseurl . 'photos/' . $photo );

        $person->appendChild( $depic );
    }

    $person->appendChild( $self->_foaf_event( 'birth' ) ) if $self->birth;
    $person->appendChild( $self->_foaf_event( 'death' ) ) if $self->death;

    my $sex = $self->sex eq 'M' ? 'male' : $self->sex eq 'F' ? 'female' : '';

    if ( $sex ) {
        my $gender = $xml->createElement( 'foaf:gender' );
        $gender->appendText( $sex );
        $person->appendChild( $gender );
    }

    for (
        $self->_foaf_rel( 'parents',  'child',   $baseurl ),
        $self->_foaf_rel( 'spouse',   'spouse',  $baseurl ),
        $self->_foaf_rel( 'siblings', 'sibling', $baseurl ),
        $self->_foaf_rel( 'children', 'parent',  $baseurl ),
        )
    {
        $person->appendChild( $_ );
    }

    $rdf->addChild( $person );

    for ( $self->parents, $self->siblings, $self->spouse, $self->children ) {
        $rdf->addChild( $_->_foaf_seealso( $baseurl ) );
    }

    return $xml->toString( 1 );
}

sub _foaf_event {
    my $self = shift;
    my $name = lc( shift );

    my $event = XML::LibXML::Element->new( 'bio:event' );
    my $type  = XML::LibXML::Element->new( 'bio:' . ucfirst( $name ) );
    my $date  = XML::LibXML::Element->new( 'bio:date' );
    my $place = XML::LibXML::Element->new( 'bio:place' );

    $date->appendText( $self->get_value( "$name date" ) );
    $place->appendText( $self->get_value( "$name place" ) );

    $type->appendChild( $date );
    $type->appendChild( $place );

    $event->appendChild( $type );

    return $event;
}

sub _foaf_rel {
    my $self    = shift;
    my $method  = shift;
    my $rel     = shift;
    my $baseurl = shift;

    my @rels;

    for my $person ( $self->$method ) {
        my $xref    = $person->xref;
        my $element = XML::LibXML::Element->new( 'rel:' . $rel . 'Of' );
        $element->setAttribute( 'rdf:resource' => "$baseurl$xref.xml#$xref" );
        push @rels, $element;
    }

    return @rels;
}

sub _foaf_seealso {
    my $self    = shift;
    my $baseurl = shift;
    my $xref    = $self->xref;
    my $url     = "$baseurl$xref.xml";
    my $urlspec = "$url#$xref";

    my $person = XML::LibXML::Element->new( 'foaf:Person' );
    $person->setAttribute( 'rdf:about' => $urlspec );

    my $name = XML::LibXML::Element->new( 'foaf:name' );
    $name->appendText( $self->label_name );

    my $seealso = XML::LibXML::Element->new( 'rdfs:seeAlso' );
    $seealso->setAttribute( 'rdf:resource' => $url );

    $person->appendChild( $name );
    $person->appendChild( $seealso );

    return $person;
}

=head3 label_name

Generates a string suitable for an C<foaf:name> element.

=cut

sub label_name {
    my $self = shift;

    return join( ' ', $self->given_names, $self->surname );
}

package Gedcom::Family;

=head2 Gedcom::Family

=head3 as_foaf( $baseurl )

Generates a FOAF (XML) string from the Gedcom::Family object. Pass
in a base url if desired.

=cut

sub as_foaf {
    my $self    = shift;
    my $baseurl = shift || '';
    my $xml     = XML::LibXML::Document->new( '1.0', 'UTF8' );

    my $rdf = $xml->createElement( 'RDF' );

    $rdf->setNamespace( $namespaces{ rdf },  'rdf' );
    $rdf->setNamespace( $namespaces{ rdfs }, 'rdfs', 0 );
    $rdf->setNamespace( $namespaces{ foaf }, 'foaf', 0 );
    $rdf->setNamespace( $namespaces{ bio },  'bio', 0 );

    $xml->setDocumentElement( $rdf );
    my $xref  = $self->xref;
    my $group = $xml->createElement( 'foaf:Group' );
    $group->setAttribute( 'rdf:about' => "$baseurl$xref.xml#$xref" );

    my $label = $xml->createElement( 'rdfs:label' );

    my $husband = $self->husband;
    my $wife    = $self->wife;
    $husband = $husband ? $husband->label_name : '(Unknown)';
    $wife    = $wife    ? $wife->label_name    : '(Unknown)';

    $label->appendText(
        join( ' ', 'The Family of', $husband, 'and', $wife ) );
    $group->appendChild( $label );

    my $type = $xml->createElement( 'rdf:type' );
    $type->setAttribute(
        'rdf:resource' => 'http://xmlns.com/wordnet/1.6/Family' );
    $group->appendChild( $type );

    foreach my $event ( $self->marriage ) {
        my $bioevent = $xml->createElement( 'bio:event' );
        my $marriage = $xml->createElement( 'bio:Marriage' );

        if ( my $datevalue = $event->date ) {
            my $date = $xml->createElement( 'bio:date' );
            $date->appendText( $datevalue );
            $marriage->appendChild( $date );
        }

        if ( my $placevalue = $event->place ) {
            my $place = $xml->createElement( 'bio:place' );
            $place->appendText( $placevalue );
            $marriage->appendChild( $place );
        }

        $bioevent->appendChild( $marriage );

        $group->appendChild( $marriage );
    }

    $rdf->appendChild( $group );

    for my $person ( $self->parents, $self->children ) {
        my $xref    = $person->xref;
        my $url     = "$baseurl$xref.xml";
        my $urlspec = "$url#$xref";

        my $member = $xml->createElement( 'foaf:member' );
        $member->setAttribute( 'rdf:resource' => $urlspec );
        $group->appendChild( $member );

        $rdf->appendChild( $person->_foaf_seealso( $baseurl ) );
    }

    return $xml->toString( 1 );
}

sub _foaf_seealso {
    my $self    = shift;
    my $person  = shift;
    my $baseurl = shift;

    my $group = XML::LibXML::Element->new( 'foaf:Group' );
    $group->setAttribute(
        'rdf:about' => $baseurl . $self->xref . '.xml#' . $self->xref );

    my $seealso = XML::LibXML::Element->new( 'rdfs:seeAlso' );
    $seealso->setAttribute(
        'rdf:resource' => $baseurl . $self->xref . '.xml' );

    my $member = XML::LibXML::Element->new( 'foaf:member' );
    $member->setAttribute( 'rdf:resource' => $baseurl
            . $person->xref . '.xml#'
            . $person->xref );

    $group->appendChild( $seealso );
    $group->appendChild( $member );

    return $group;
}

=head1 AUTHOR

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;
