#!/usr/bin/perl -I lib
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

use URI::Encode qw(uri_encode uri_decode);
my $port = $ARGV[0];
my $casUrl = $ARGV[1];

$casUrl = "https://cas.example.org:8443/cas" unless defined $casUrl;

{
    package MyWebServer;

    use strict;
    use warnings;
    use utf8;
    use XML::Tidy;
    use HTTP::Server::Simple::CGI;
    use URI::Encode qw(uri_encode uri_decode);
    use base qw(HTTP::Server::Simple::CGI);
    use XML::XPath;
    use XML::XPath::XMLParser;
    use LWP::UserAgent;
    use HTML::Entities;
    use XML::LibXML;
    use Custom::SAML qw(createSaml);
    use threads ('yield',
        'stack_size' => 64 * 4096,
        'exit'       => 'threads_only',
        'stringify');

    my $ua = LWP::UserAgent->new(ssl_opts => { SSL_verify_mode => 0, verify_hostname => 0 },);
    $ua->agent("Cas-apereo-cli/0.1");


    # for / handle the ticket
    my %dispatch = (
        '/saml' => \&validate_saml_ticket,
        '/'     => \&links,
        '/cas'  => \&validate_cas_ticket,
        '/pid'  => \&getPid,
        # ...
    );

    sub getPid {
        my $cgi = shift;

        print $cgi->header, "$$";
    }

    sub handle_request {
        my $self = shift;
        my $cgi = shift;

        my $path = $cgi->path_info();
        my $handler = $dispatch{$path};

        if (ref($handler) eq "CODE") {
            print "HTTP/1.0 200 OK\r\n";
            $handler->($cgi);

        }
        else {
            print "HTTP/1.0 404 Not found\r\n";
            print $cgi->header,
                $cgi->start_html('Not found'),
                $cgi->h1('Not found'),
                $cgi->end_html;
        }
    }

    sub getUdcId {
        my $res = shift;

        my $samlResponse = $res->content;
        my $xp = XML::XPath->new(xml => $samlResponse);

        my $udcid = $xp->findvalue("/*[local-name() = 'Envelope']" .
            "/*[local-name() = 'Body']" .
            "/*[local-name() = 'Response']" .
            "/*[local-name() = 'Assertion']" .
            "/*[local-name() = 'AttributeStatement']" .
            "/*[local-name() = 'Attribute' and \@AttributeName = 'UDC_IDENTIFIER']" .
            "/*[local-name() = 'AttributeValue']" .
            "/text()");
        return $udcid;
    }
    sub getSamlSuccess {
        my $res = shift;

        my $samlResponse = $res->content;
        my $xp = XML::XPath->new(xml => $samlResponse);

        return $xp->findvalue("/*[local-name() = 'Envelope']" .
            "/*[local-name() = 'Body']" .
            "/*[local-name() = 'Response']" .
            "/*[local-name() = 'Status']" .
            "/*[local-name() = 'StatusCode']" .
            "/\@Value");
    }
    sub getSamlUser {
        my $res = shift;

        my $samlResponse = $res->content;
        my $xp = XML::XPath->new(xml => $samlResponse);

        return $xp->findvalue("/*[local-name() = 'Envelope']" .
            "/*[local-name() = 'Body']" .
            "/*[local-name() = 'Response']" .
            "/*[local-name() = 'Assertion']" .
            "/*[local-name() = 'AttributeStatement']" .
            "/*[local-name() = 'Subject']" .
            "/*[local-name() = 'NameIdentifier']" .
            "/text()");
    }
    sub getCasUser {
        my $res = shift;

        my $samlResponse = $res->content;
        my $xp = XML::XPath->new(xml => $samlResponse);

        return $xp->findvalue("/cas:serviceResponse" .
            "/cas:authenticationSuccess" .
            "/cas:user" .
            "/text()");
    }

    sub createLinks
    {
        my $cgi = shift;

        my $samlService = uri_encode("http://localhost:$port/saml");
        my $casService = uri_encode("http://localhost:$port/cas");
        
        $cgi->ul($cgi->li([ "<a href=\"$casUrl/login?TARGET=$samlService\">SAML Auth</a>",
            "<a href=\"$casUrl/login?service=$casService\">CAS Auth</a>" ]));
    }

    sub links {
        my $cgi = shift; # CGI.pm object
        return if !ref $cgi;

        print $cgi->header,
            $cgi->start_html("Hello");

        print $cgi->h1("Cas CLI Tester"),
            $cgi->p("This service supports SAML or regular CAS auth testing"),
            createLinks($cgi),
            print $cgi->end_html;
    }

    sub validate_saml_ticket {
        my $cgi = shift; # CGI.pm object
        return if !ref $cgi;

        my $ticket = $cgi->param('SAMLart');
        if ("$ticket" eq "") {
            print $cgi->header,
                $cgi->start_html("Hello"),
                $cgi->h1("No ticket, you did not come from CAS. $ticket"),
                $cgi->end_html;
        }
        else {
            print $cgi->header,
                $cgi->start_html("Hello");

            my $encodedUri = uri_encode("http://localhost:$port/saml");
            my $req = HTTP::Request->new(POST => "$casUrl/samlValidate?TARGET=$encodedUri",
                [ 'Content-Type' => 'text/xml' ]);
            my $saml = createSaml($ticket);
            $req->content($saml);

            my $stringRequest = $req->as_string();
            # Pass request to the user agent and get a response back
            my $res = $ua->request($req);

            # Check the outcome of the response
            if ($res->is_success) {
                # reformat SAML response for display
                my $tidy_obj = XML::Tidy->new('xml' => $res->content);
                $tidy_obj->tidy('  ');
                my $content = $tidy_obj->toString();
                print $cgi->h1("Ticket Validation"),
                    $cgi->p("Ticket \"$ticket\" received."),
                    createLinks($cgi),
                    $cgi->ul($cgi->li([ "user: " . getSamlUser($res), "udcid: " .
                        getUdcId($res), "saml success: " . getSamlSuccess($res) ])),
                    $cgi->pre(encode_entities($stringRequest)), "\n",
                    $cgi->pre(encode_entities($res->as_string())), "\n",
                    $cgi->pre(encode_entities($content)), "\n";
            }
            else {
                print $cgi->h1("Error in http call");
                print $res->status_line, "\n";
                print $saml, "\n";
                print $cgi->pre(encode_entities($stringRequest)), "\n";
                print encode_entities($res->content), "\n";
            }
            print $cgi->end_html;
        }
    }

    sub validate_cas_ticket {
        my $cgi = shift; # CGI.pm object
        return if !ref $cgi;

        my $ticket = $cgi->param('ticket');
        if ("$ticket" eq "") {
            print $cgi->header,
                $cgi->start_html("Hello"),
                $cgi->h1("No ticket, you did not come from CAS. $ticket"),
                $cgi->end_html;
        }
        else {
            print $cgi->header,
                $cgi->start_html("Hello");

            my $serviceUri = uri_encode("http://localhost:$port/cas");
            my $req = HTTP::Request->new(GET => "$casUrl/serviceValidate?service=$serviceUri&ticket=$ticket");

            # TODO validate the StatusCode == Success

            # Pass request to the user agent and get a response back
            my $res = $ua->request($req);

            # Check the outcome of the response
            if ($res->is_success) {
                # create new   XML::Tidy object by loading:  MainFile.xml
                my $tidy_obj = XML::Tidy->new('xml' => $res->content);
                $tidy_obj->tidy('  ');
                my $content = $tidy_obj->toString();
                print $cgi->h1("Ticket Validation"),
                    $cgi->p("Ticket \"$ticket\" received."),
                    createLinks($cgi),
                    $cgi->ul($cgi->li([ "cas user: " . getCasUser($res) ])),
                    $cgi->pre(encode_entities($content)), "\n";
            }
            else {
                print $cgi->h1("Error in http call");
                print createLinks($cgi),
                print $res->status_line, "\n";
                print encode_entities($res->content), "\n";
            }
            print $cgi->end_html;
        }
    }
}

my $webServer = MyWebServer->new($ARGV[0]);
my $processId = $webServer->background();
my $service = uri_encode("http://localhost:$port/saml");
print "WARNING: This server stays running until you kill pid: $processId\n\n";
print "saml validate: $casUrl/login?TARGET=$service\n";
$service = uri_encode("http://localhost:$port/cas");
print "cas validate: $casUrl/login?service=$service\n";
