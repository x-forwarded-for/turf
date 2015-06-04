require_relative '../test_helper'

class RequestArrayTest < MiniTest::Test

  def setup
    @ws, @ws_port = start_basic_webrick
  end

  def teardown
    @ws.terminate
  end

  def test_parallel
    io = StringIO.new "GET / HTTP/1.1\r\n\r\n"
    r = Turf::Request.new io, hostname: "127.0.0.1", port: @ws_port
    rs = r * 12
    assert_equal(0, rs.done.length)
    rs.parallel
    puts rs.inspect
    assert_equal(12, rs.done.length)
  end

end
