require_relative '../test_helper'

class ProxyTest < MiniTest::Test

  PROXY_RUNNING = /\ARunning on (.*):(?<proxy_port>[0-9]+)\z/

  class DummyUI
    attr_accessor :proxy_thread
    def info(s)
    end
    def ask(q)
    end
  end

  def setup
    @ui = DummyUI.new
    @m = Mutex.new
    @stopped = ConditionVariable.new
  end

  def start_proxy
    port = rand(1024..65535)
    t = Thread.new do
      @m.synchronize {
        @p = Turf::Proxy.new(port: port, ui: @ui)
        @p.start_sync
        @stopped.signal
      }
    end
    return t, port
  end

  def test_irb_stop_after_start
    def @ui.info(message)
      @proxy_thread.raise IRB::Abort if message =~ PROXY_RUNNING
    end

    @m.synchronize {
      @ui.proxy_thread, port = start_proxy
      @stopped.wait(@m)
    }
    assert_empty(@p.requests)
  end

  def test_new
    def @ui.ask(q)
      "f"
    end

    p, p_port = start_proxy
    ws, ws_port = start_basic_webrick

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: false)
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
  end

  def test_mitm_ssl
    def @ui.ask(q)
      ""
    end

    p, p_port = start_proxy
    ws, ws_port = start_tls_webrick

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: ws_port, use_ssl: true)
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
  end

end
