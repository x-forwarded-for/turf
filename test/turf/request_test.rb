require_relative '../test_helper'

require 'webrick'

class RequestTest < MiniTest::Test

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
    @io = StringIO.new "GET http://example.org/ HTTP/1.1\r\n\r\n"
    r = Turf::Request.new @io
    r.run
    assert_equal(r.response.status, '400')
    assert_equal(r.response.inspect, '<400 349 text/html>')
    assert_equal(r.response.to_s.include?('<title>400 - Bad Request</title>'), true)
  end

end
