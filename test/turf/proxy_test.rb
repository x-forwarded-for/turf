require_relative '../test_helper'

class ProxyTest < MiniTest::Test

  PROXY_RUNNING = /\ARunning on (.*):(?<proxy_port>[0-9]+)\z/

  class DummyUI
    attr_accessor :proxy_thread
    attr_accessor :message
    def info(s, from: nil)
    end
    def ask(q)
    end
  end

  def setup
    @ui = DummyUI.new
    @m = Mutex.new
    @started = ConditionVariable.new
    @stopped = ConditionVariable.new
  end

  def start_proxy
    port = rand(1024..65535)
    t = Thread.new do
      @m.synchronize {
        @p = Turf::Proxy.new(port: port, ui: @ui)
        @p.bind
        @started.signal
      }
      @p.serve
      @stopped.signal
    end
    return t, port
  end

  def test_irb_stop_after_start

    def @ui.info(message, from: nil)
      @message = message
      @proxy_thread.raise IRB::Abort
    end

    @m.synchronize {
      @ui.proxy_thread, port = start_proxy
      @stopped.wait(@m)
    }
    assert_match(PROXY_RUNNING, @ui.message)
    assert_empty(@p.requests)
  end

  def test_new
    def @ui.ask(q)
      "f"
    end

    p = nil
    p_port = nil
    @m.synchronize {
      p, p_port = start_proxy
      @started.wait(@m)
    }
    ws, ws_port = start_basic_webrick
    r = Turf::get("http://127.0.0.1:#{ws_port}/")
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
    assert_equal(1, @p.requests.length)
  end

  def test_mitm_ssl
    def @ui.ask(q)
      ""
    end

    p = nil
    p_port = nil
    @m.synchronize {
      p, p_port = start_proxy
      @started.wait(@m)
    }
    ws, ws_port = start_tls_webrick

    r = Turf::get("https://127.0.0.1:#{ws_port}/")
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    ws.terminate
    assert_equal(2, @p.requests.length)
  end

end
