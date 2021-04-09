use Cro::HTTP::Router;
use Cro::HTTP::Client;
use Cro::HTTP::Server;
use Cro::TLS:auth<github:seaker>;
use Test;

constant HTTP_TEST_PORT = 31318;
constant HTTPS_TEST_PORT = 31319;
constant %ca := { server-ca-file => 't/certs-and-keys/ca-crt.pem' };
constant %key-cert := {
    server-private-key-file => 't/certs-and-keys/server-key.pem',
    server-certificate-file => 't/certs-and-keys/server-crt.pem'
};

my $app = route {
    http 'GET', -> {
        content 'text/plain', 'GET';
    }
    http 'CUSTOM', -> {
        content 'text/plain', 'CUSTOM';
    }
}

{
    my $http-server = Cro::HTTP::Server.new(
        port => HTTP_TEST_PORT,
        application => $app,
        :allowed-methods(<GET CUSTOM>)
    );

    $http-server.start;
    LEAVE $http-server.stop;

    my $base = "http://localhost:{HTTP_TEST_PORT}";
    my $c = Cro::HTTP::Client.new;
    given await $c.get("$base/") -> $resp {
        ok $resp ~~ Cro::HTTP::Response, 'GET using http method works';
        is await($resp.body-text), 'GET', 'Body text is correct';
    }

    given await $c.request('CUSTOM', "$base") -> $resp {
        ok $resp ~~ Cro::HTTP::Response, 'CUSTOM using http method works';
        is await($resp.body-text), 'CUSTOM', 'Body text is correct';
    }
}

if supports-alpn() {
    my $https-server = Cro::HTTP::Server.new(
        port => HTTPS_TEST_PORT,
        application => $app,
        tls => %key-cert,
        :allowed-methods(<GET CUSTOM>),
        :http<2>
    );

    $https-server.start;
    LEAVE $https-server.stop;

    my $base = "https://localhost:{HTTPS_TEST_PORT}";
    my $c = Cro::HTTP::Client.new;
    given await $c.get("$base/", :%ca) -> $resp {
        ok $resp ~~ Cro::HTTP::Response, 'GET using http method works';
        is await($resp.body-text), 'GET', 'Body text is correct';
    }

    given await $c.request('CUSTOM', "$base", :%ca) -> $resp {
        ok $resp ~~ Cro::HTTP::Response, 'CUSTOM using http method works';
        is await($resp.body-text), 'CUSTOM', 'Body text is correct';
    }
}

done-testing;
