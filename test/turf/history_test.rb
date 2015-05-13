require_relative '../test_helper'
require_relative 'dummy_server'

class HistoryTest < MiniTest::Test
  include DummyServer

  def test_new
    ws, ws_port = start_basic_webrick
    wait_until_online '127.0.0.1', ws_port

    h_len = Turf::History.instance.length
    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: false)
    r.run

    assert_equal(1, Turf::History.instance.length - h_len)
    assert_includes(Turf::History.instance.inspect, "200")
    ws.terminate
  end

end
