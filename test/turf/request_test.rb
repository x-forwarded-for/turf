require_relative '../test_helper'

class RequestTest < MiniTest::Test

  def setup
    @ws, @ws_port = start_basic_webrick
  end

  def teardown
    @ws.terminate
  end

  def test_new
    io = StringIO.new "GET / HTTP/1.1\r\n\r\n"
    r = Turf::Request.new io, hostname: "example.org"
    assert_equal(r.hostname, "example.org")
    assert_equal(r.port, 80)
    assert_equal(r.url, "/")
  end

  def test_new_proxy_http
    io = StringIO.new "GET http://example.org/ HTTP/1.1\r\n\r\n"
    r = Turf::Request.new io
    assert_equal(r.hostname, "example.org")
    assert_equal(r.port, 80)
    assert_equal(r.url, "/")
  end

  def test_new_proxy_https_connect
    io = StringIO.new "CONNECT example.org:4343 HTTP/1.1\r\n\r\n"
    r = Turf::Request.new io
    assert_equal(r.hostname, "example.org")
    assert_equal(r.port, 4343)
    assert_equal(r.to_s, "CONNECT example.org:4343 HTTP/1.1\r\n\r\n")
  end

  def test_run
    r = Turf::get("http://127.0.0.1:#{@ws_port}/")
    r.run
    assert_equal('200', r.response.status)
    assert_includes(r.response.inspect, 'text/plain')
    assert_includes(r.response.to_s, 'Hello, world!')
  end

  def test_chunked
    io = StringIO.new "GET http://example.org/ HTTP/1.1\r\n" +
                       "Transfer-Encoding: chunked\r\n\r\n" +
                       "8\r\nabcdefgh\r\n0\r\n\r\n"
    r = Turf::Request.new io
    assert_equal(r.raw_content, "8\r\nabcdefgh\r\n0\r\n\r\n")
  end

  def test_inject_at
    io = StringIO.new "GET http://example.org/ HTTP/1.1\r\n" +
                       "X-Forwarded-For: 169.254.1.1\r\n\r\n"
    r = Turf::Request.new io
    ira = r.inject_at("169.254.1.1", ["10.0.0.1", "192.168.1.1"])
    assert_equal(ira.length, 2)
  end

  def test_inject_at_post
    io = StringIO.new "POST http://example.org/ HTTP/1.1\r\n" +
                      "Content-Length: 8\r\n" +
                      "Content-Type: application/x-www-form-urlencoded\r\n\r\n" +
                      "abcdefgh"
    r = Turf::Request.new io
    ira = r.inject_at("defgh", ["ijk", "l"])
    assert_equal(ira.length, 2)
    assert_equal(ira[0].raw_content, "abcijk")
    assert_equal(ira[1].raw_content, "abcl")
  end

  def test_post_alias
    r = Turf::post("http://127.0.0.1:#{@ws_port}/", "test" => 123)
    assert_equal(r.raw_content, "test=123")
    cl = r.get_header(r.headers, "Content-Length")
    assert_equal(cl.length, 1)
    assert_equal(cl.first, "8")
  end

  def test_multipart_alias
    r = Turf::multipart("http://127.0.0.1:#{@ws_port}/", "test" => 123, "file" => File.open("/etc/issue"))
    assert_includes(r.raw_content, "Content-Disposition: form-data; name=\"test\"\r\n\r\n123")
  end

end
