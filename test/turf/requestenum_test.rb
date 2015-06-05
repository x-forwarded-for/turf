require_relative '../test_helper'

class RequestEnumTest < MiniTest::Test

  def setup
    @ws, @ws_port = start_basic_webrick
    @default_io = "POST http://127.0.0.1:#{@ws_port}/ HTTP/1.1\r\n" +
                  "Content-Length: 8\r\n" +
                  "Content-Type: application/x-www-form-urlencoded\r\n\r\n" +
                  "abcdefgh"
  end

  def teardown
    @ws.terminate
  end

  def test_take
    r = Turf::Request.new StringIO.new(@default_io)
    re = r.lazy_inject_at("defgh", (1..Float::INFINITY).lazy.map(&:to_s))
    ra1 = re.take(50)
    assert_equal(50, ra1.length)
    ra2 = re.take(10)
    assert_equal(10, ra2.length)
  end

  def test_run_while
    r = Turf::Request.new StringIO.new(@default_io)
    re = r.lazy_inject_at("gh", (1..Float::INFINITY).lazy.map(&:to_s))
    ra = re.run_while { |r| r.response.status == "200" }
    assert_equal(12, ra.length)
  end

  def test_run_until
    r = Turf::Request.new StringIO.new(@default_io)
    re = r.lazy_inject_at("gh", (1..Float::INFINITY).lazy.map(&:to_s))
    ra = re.run_until { |r| r.response.status != "200" }
    assert_equal(12, ra.length)
  end
end
