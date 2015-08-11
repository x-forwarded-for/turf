require_relative "../test_helper"

class ResponseTest < MiniTest::Test

  def setup
    @r = Turf::get("http://example.org/")
  end

  def test_new
    response_io = "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\na"
    response = Turf::Response.new(StringIO.new(response_io), @r)
    assert_equal("a", response.content)
  end

  def test_chunked
    response_io = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nabcd\r\n0\r\n\r\n"
    response = Turf::Response.new(StringIO.new(response_io), @r)
    assert_equal("abcd", response.content)
  end

  def test_gzip
    response_io = "HTTP/1.1 200 OK\r\nContent-Length: 35\r\nContent-Encoding: gzip\r\n\r\n\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\xB3Q\xD4\xD5U(\xCB\xCFLQP\xD0\xD5\xB5\xE3\x02\x00\xFB\xFE\xDA7\x0F\x00\x00\x00"
    response = Turf::Response.new(StringIO.new(response_io), @r)
    assert_equal("<!-- void  -->\n", response.content)
  end


  def test_deflate
    response_io = "HTTP/1.1 200 OK\r\nContent-Length: 16\r\nContent-Encoding: deflate\r\n\r\n\xabVJ\xccI-*I-V\xb2\x8a\x8e\xad\x05\x00"
    response = Turf::Response.new(StringIO.new(response_io), @r)
    assert_equal('{"alertes":[]}', response.content)
  end

  def test_cookies
    response_io = "HTTP/1.1 200 OK\r\nSet-Cookie: PHPSESS_ID=0xdeadbeef\r\n\r\n"
    response = Turf::Response.new(StringIO.new(response_io), @r)
    assert_equal("0xdeadbeef", response.cookies["PHPSESS_ID"])
  end

end
