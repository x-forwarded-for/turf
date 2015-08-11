require_relative "../test_helper"

class HistoryTest < MiniTest::Test

  def test_new
    ws, ws_port = start_basic_webrick

    h = Turf::Session.instance.history
    h_len = h.length
    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: false)
    r.run

    assert_equal(1, h.length - h_len)
    assert_includes(h.inspect, "200")
    ws.terminate
  end

end
