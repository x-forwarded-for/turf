require_relative '../test_helper'
require_relative 'dummy_server'

class ProxyTest < MiniTest::Test
  include DummyServer

  def start_forward_proxy
    Thread.new {
      rs = Turf::proxy :rules => [[ proc {|x| true}, :forward ]]
    }
  end

  def test_new
    p = start_forward_proxy
    ws = start_basic_webrick
    wait_until_online '127.0.0.1', 8000
    wait_until_online '127.0.0.1', 8080

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: 8000, use_ssl: false)
    r.run proxy: "http://127.0.0.1:8080"

    p.raise IRB::Abort
    ws.terminate
  end

end
