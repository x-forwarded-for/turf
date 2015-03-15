require_relative '../test_helper'
require_relative 'dummy_server'

class RequestTest < MiniTest::Test
  include DummyServer

  def setup
    @ws, @ws_port = start_basic_webrick
    wait_until_online "127.0.0.1", @ws_port
  end

  def teardown
    @ws.terminate
  end

  def test_new
    @io = StringIO.new "GET / HTTP/1.1\r\n\r\n"
    r = Turf::Request.new @io, hostname: "example.org"
    assert_equal(r.hostname, "example.org")
    assert_equal(r.port, 80)
    assert_equal(r.url, "/")
  end

  def test_new_proxy_http
    @io = StringIO.new "GET http://example.org/ HTTP/1.1\r\n\r\n"
    r = Turf::Request.new @io
    assert_equal(r.hostname, "example.org")
    assert_equal(r.port, 80)
    assert_equal(r.url, "/")
  end

  def test_new_proxy_https
    @io = StringIO.new "GET https://example.org/ HTTP/1.1\r\n\r\n"
    r = Turf::Request.new @io
    assert_equal(r.hostname, "example.org")
    assert_equal(r.port, 443)
    assert_equal(r.url, "/")
  end

  def test_new_proxy_https_connect
    @io = StringIO.new "CONNECT example.org:4343 HTTP/1.1\r\n\r\n"
    r = Turf::Request.new @io
    assert_equal(r.hostname, "example.org")
    assert_equal(r.port, 4343)
    assert_equal(r.to_s, "CONNECT example.org:4343 HTTP/1.1\r\n\r\n")
  end

  def test_run
    @io = StringIO.new "GET http://127.0.0.1:#{@ws_port}/ HTTP/1.1\r\n\r\n"
    r = Turf::Request.new @io
    r.run
    assert_equal(r.response.status, '200')
    assert_equal(r.response.to_s.include?('Hello, world!'), true)
  end

  def test_chunked
     @io = StringIO.new "GET http://example.org/ HTTP/1.1\r\n" +
                        "Transfer-Encoding: chunked\r\n\r\n" +
                        "8\r\nabcdefgh\r\n0\r\n\r\n"
     r = Turf::Request.new @io
     assert_equal(r.raw_content, "8\r\nabcdefgh\r\n0\r\n\r\n")
  end

end
