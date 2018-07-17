# Copyright [2018] [Athabasca University IT]
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#         http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Custom::SAML;
use strict;
use warnings;
use DateTime;

use Exporter qw(import);
 
our @EXPORT_OK = qw(createSaml);


sub createSaml
{
    my $ticket = shift;

    my $soapUri = 'http://schemas.xmlsoap.org/soap/envelope/';
    my $samlUri = 'urn:oasis:names:tc:SAML:1.0:protocol';
    my $doc = XML::LibXML::Document->createDocument('1.0','UTF-8');
    my $envelope = $doc->createElementNS($soapUri, 'Envelope');
    my $header = $doc->createElementNS($soapUri, 'Header');
    my $body = $doc->createElementNS($soapUri, 'Body');
    my $request = $doc->createElementNS($samlUri, 'Request');
    my $assertionArtifact = $doc->createElementNS($samlUri, 'AssertionArtifact');

    $envelope->appendChild($header);
    $envelope->appendChild($body);
    $body->appendChild($request);
    $request->appendChild($assertionArtifact);
    $assertionArtifact->appendTextNode($ticket);
    $doc->setDocumentElement( $envelope );

    $request->setAttribute('MajorVersion', '1');
    $request->setAttribute('MinorVersion', '1');
    $request->setAttribute('RequestID', DateTime->now()->epoch());
    $request->setAttribute('IssueInstant', DateTime->now()->iso8601().'Z');

    return $doc->toString();

}

