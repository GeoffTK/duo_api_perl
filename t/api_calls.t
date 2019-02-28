use Test::Spec;
use Test::More;
use Test::Deep;
use Test::Exception;
use URI;
use URI::QueryParam;

use Duo::API;
use LWP::UserAgent;
use Time::HiRes;

use constant SEED => 987;

describe "A duo api client" => sub {
    my $sut;
    my $mock_response;
    my @captured_requests;
    my $last_captured_req;
    my $ikey;
    my $skey;
    my $host;

    before each => sub {
        $mock_response = mock();
        @captured_requests = ();

        $ikey = 'ikey' . rand();
        $skey = 'skey' . rand();
        $host = 'host' . rand();
        $sut = Duo::API->new($ikey, $skey, $host);

        LWP::UserAgent->stubs(request => sub {
            my ($ua, $req) = @_;
            push @captured_requests, $req;
            $last_captured_req = $req;
            return $mock_response;
        });

        $mock_response->stubs(
            content => '{"stat":"OK", "response": [{"thing": 1}, {"thing": 2}], "metadata": {"next_offset": null}}',
            code => 200,
        );
    };

    describe "json_api_call method" => sub {

        it "creates the expected GET request" => sub {
            my $res = $sut->json_api_call('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });

            is($last_captured_req->uri->host, $host);
            is($last_captured_req->uri->path, '/admin/v1/admins');
            is($last_captured_req->uri->query_param('limit'), "25");
            is($last_captured_req->uri->query_param('offset'), "0");
            is($last_captured_req->uri->query_param('account_id'), "D1234567890123456789");
            is($last_captured_req->method, 'GET');
        };

        it "creates the expected POST request" => sub {
            my $res = $sut->json_api_call('POST', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });

            my $dummy_uri = URI->new("https://example.com");
            $dummy_uri->query($last_captured_req->content);
            is($last_captured_req->uri->host, $host);
            is($last_captured_req->uri->path, '/admin/v1/admins');
            is($dummy_uri->query_param('limit'), "25");
            is($dummy_uri->query_param('offset'), "0");
            is($dummy_uri->query_param('account_id'), "D1234567890123456789");
            is($last_captured_req->method, 'POST');
        };

        it "returns the expected data" => sub {
            my $res = $sut->json_api_call('POST', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });

            cmp_bag($res, [{ thing => 1 }, { thing =>2 }]);
        };
    };

    describe "json_api_call_full" => sub {

        it "creates the expected GET request" => sub {
            my $res = $sut->json_api_call_full('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });

            is($last_captured_req->uri->host, $host);
            is($last_captured_req->uri->path, '/admin/v1/admins');
            is($last_captured_req->uri->query_param('limit'), "25");
            is($last_captured_req->uri->query_param('offset'), "0");
            is($last_captured_req->uri->query_param('account_id'), "D1234567890123456789");
            is($last_captured_req->method, 'GET');
        };

        it "creates the expected POST request" => sub {
            my $res = $sut->json_api_call_full('POST', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });

            my $dummy_uri = URI->new("https://example.com");
            $dummy_uri->query($last_captured_req->content);
            is($last_captured_req->uri->host, $host);
            is($last_captured_req->uri->path, '/admin/v1/admins');
            is($dummy_uri->query_param('limit'), "25");
            is($dummy_uri->query_param('offset'), "0");
            is($dummy_uri->query_param('account_id'), "D1234567890123456789");
            is($last_captured_req->method, 'POST');
        };

        it "returns the expected data" => sub {
            my $res = $sut->json_api_call_full('POST', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });

            cmp_deeply($res, {
                stat     => 'OK',
                response => bag({ thing => 1 }, { thing =>2 }),
                metadata => { next_offset => undef },
            });
        };
    };

    describe "json_paging_api_call method" => sub {
        it "returns a Duo::Api::Iterator" => sub {
            my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });
            isa_ok($iter, "Duo::API::Iterator");
        };

        it "doesn't make an api call until next is called on the iterator" => sub {
            my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });
            is(scalar(@captured_requests), 0);
        };

        it "creates the expected GET request when next is called" => sub {
            my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });
            $iter->next();

            ($last_captured_req) = @captured_requests;
            is($last_captured_req->uri->host, $host);
            is($last_captured_req->uri->path, '/admin/v1/admins');
            is($last_captured_req->uri->query_param('limit'), "25");
            is($last_captured_req->uri->query_param('offset'), "0");
            is($last_captured_req->uri->query_param('account_id'), "D1234567890123456789");
            is($last_captured_req->method, 'GET');
        };

        it "retrieves the expected data" => sub {
            my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });
            my @response_data = $iter->all();

            cmp_bag(\@response_data, [{thing => 1}, {thing => 2}]);
        };

        it "uses client default page size if not specified" => sub {
          my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
              offset => 0,
              account_id => 'D1234567890123456789',
          });
          $iter->next();

          ($last_captured_req) = @captured_requests;
          is($last_captured_req->uri->query_param('limit'), "100");
        };

        it "uses client default offset if not specified" => sub {
          my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
              account_id => 'D1234567890123456789',
          });
          $iter->next();

          ($last_captured_req) = @captured_requests;
          is($last_captured_req->uri->query_param('offset'), "0");
        };

        it "dies if the response data isn't a list" => sub {
            $mock_response->stubs(
                content => '{"stat":"OK", "response": {"thing": 1}}'
            );

            my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });

            throws_ok { $iter->next() } qr/Expected response data to be a list/, '';
        };

        it "makes multiple api calls if there is more data to retrieve" => sub {
            $mock_response->stubs(
                content => sub {
                    if (@captured_requests == 1) {
                        return '{"stat":"OK", "response": [{"thing": 1}, {"thing": 2}], "metadata": {"next_offset": 2}}';
                    }

                    return '{"stat":"OK", "response": [{"thing": 3}, {"thing": 4}], "metadata": {"next_offset": null}}';
                }
            );

            my $iter = $sut->json_paging_api_call('GET', '/admin/v1/admins', {
                limit => 25,
                offset => 0,
                account_id => 'D1234567890123456789',
            });
            my @response_data = $iter->all();
            cmp_bag(\@response_data, [
              { thing => 1 },
              { thing => 2 },
              { thing => 3 },
              { thing => 4 }
            ]);

            my ($req1, $req2) = @captured_requests;
            is($req1->uri->host, $host);
            is($req1->uri->path, '/admin/v1/admins');
            is($req1->uri->query_param('limit'), "25");
            is($req1->uri->query_param('offset'), "0");
            is($req1->uri->query_param('account_id'), "D1234567890123456789");
            is($req1->method, 'GET');

            is($req2->uri->host, $host);
            is($req2->uri->path, '/admin/v1/admins');
            is($req2->uri->query_param('limit'), "25");
            is($req2->uri->query_param('offset'), "2");
            is($req2->uri->query_param('account_id'), "D1234567890123456789");
            is($req2->method, 'GET');
        };
    };

    describe "make_request method" => sub {
        my @calculate_backoff_calls;
        my @sleep_calls = [];
        my @response_codes;
        my $req = mock();
        $req->stubs(
            as_string => "I am a request",
        );

        before each => sub {
            @calculate_backoff_calls = ();
            @sleep_calls = ();
            @response_codes = ();

            $mock_response->stubs(
                code => sub {
                    return shift(@response_codes) || 200;
                },
            );

            $sut->stubs(
                calculate_backoff => sub {
                    push @calculate_backoff_calls, $_[1];
                    return $_[1];
                },
            );

            Time::HiRes->stubs(
                sleep => sub {
                    push @sleep_calls, $_[0];
                },
            );
        };

        it "makes a single call when 200 response" => sub {
            @response_codes = (200);
            my $resp = $sut->make_request($req);

            is($resp, $mock_response);
            is(@captured_requests, 1);
            is($last_captured_req, $req);
            is(@calculate_backoff_calls, 0);
            is(@sleep_calls, 0);
        };

        it "retries after being rate limited" => sub {
            @response_codes = (429, 200);
            my $resp = $sut->make_request($req);

            is($resp, $mock_response);
            cmp_deeply(\@captured_requests, [$req, $req]);

            # Calculate backoff was mocked to return whatever retry attempt this was
            cmp_deeply(\@calculate_backoff_calls, [0]);
            cmp_deeply(\@sleep_calls, [0]);
        };

        it "will only make a max of 7 requests before stopping retries" => sub {
            @response_codes = (429, 429, 429, 429, 429, 429, 429, 429, 429,
                429, 429, 429, 429, 429, 429);

            my $resp = $sut->make_request($req);

            is($resp, $mock_response);
            cmp_deeply(\@captured_requests, [$req, $req, $req, $req, $req, $req, $req]);

            # Calculate backoff was mocked to return whatever retry attempt this was
            cmp_deeply(\@calculate_backoff_calls, [0, 1, 2, 3, 4, 5]);
            cmp_deeply(\@sleep_calls, [0, 1, 2, 3, 4, 5]);
        };
    };

    describe "calculate_backoff method" => sub {
        my @random_nums;

        before each => sub {
            # Capture what any rand() calls will generate
            srand(SEED);
            @random_nums = map(rand(), (1..100));
            srand(SEED);
        };

        it "backs off at the proper rate and adds some randomness" => sub {
            is($sut->calculate_backoff(0), 1 + $random_nums[0]);
            is($sut->calculate_backoff(1), 2 + $random_nums[1]);
            is($sut->calculate_backoff(2), 4 + $random_nums[2]);
            is($sut->calculate_backoff(3), 8 + $random_nums[3]);
            is($sut->calculate_backoff(4), 16 + $random_nums[4]);
            is($sut->calculate_backoff(5), 32 + $random_nums[5]);
            is($sut->calculate_backoff(6), 32 + $random_nums[6]);
            is($sut->calculate_backoff(10), 32 + $random_nums[7]);
        };
    };
};

runtests;
