require_relative '../test_helper'
require_relative 'dummy_server'

class ProxyTest < MiniTest::Test
  include DummyServer

  def start_forward_proxy
    port = rand(1024..65535)
    p = Thread.new {
      rs = Turf::proxy :port => port, :rules => [
        [ proc {|x| x.method == "CONNECT"}, :mitm_ssl],
        [ proc {|x| true}, :forward ]
      ]
    }
    return p, port
  end

  def test_new
    p, p_port = start_forward_proxy
    ws, ws_port = start_basic_webrick
    wait_until_online '127.0.0.1', ws_port
    wait_until_online '127.0.0.1', p_port

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: false)
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
  end

  def test_mitm_ssl
    p, p_port = start_forward_proxy
    ws, ws_port = start_tls_webrick
    wait_until_online '127.0.0.1', ws_port
    wait_until_online '127.0.0.1', p_port

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: true)
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
  end

end
