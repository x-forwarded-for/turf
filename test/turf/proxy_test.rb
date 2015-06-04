require_relative '../test_helper'

class ProxyTest < MiniTest::Test

  def start_forward_proxy
    port = rand(1024..65535)
    p = Thread.new do
      rs = Turf::proxy(port: port) { |r|
        next :mitm_ssl if r.method == "CONNECT"
        next :forward
      }
    end
    return p, port
  end

  def test_new
    p, p_port = start_forward_proxy
    ws, ws_port = start_basic_webrick

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: false)
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
  end

  def test_mitm_ssl
    p, p_port = start_forward_proxy
    ws, ws_port = start_tls_webrick

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: true)
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
  end

end
