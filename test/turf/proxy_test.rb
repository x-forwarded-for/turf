require_relative '../test_helper'

class ProxyTest < MiniTest::Test

  PROXY_RUNNING = /\ARunning on (.*):(?<proxy_port>[0-9]+)\z/

  class DummyUI

    attr_accessor :proxy_thread
    attr_accessor :message

    def info(s, from: nil)
    end

    def ask(q)
      ""
    end

  end

  def setup
    @ui = DummyUI.new
    @m = Mutex.new
    @started = ConditionVariable.new
  end

  def start_proxy
    port = rand(1024..65535)
    @m.synchronize {
      t = Thread.new do
        begin
          @m.synchronize {
            @p = Turf::Proxy.new(port: port, ui: @ui)
            @p.bind
            @started.signal
          }
          @p.serve
        rescue Errno::EADDRINUSE => e
          puts "Unlucky run :("
        end
      end
      @ui.proxy_thread = t
      @started.wait(@m)
      return t, port
    }
  end

  def test_irb_stop_after_start
    def @ui.info(message, from: nil)
      @message = message
      @proxy_thread.raise IRB::Abort
    end

    @ui.proxy_thread, port = start_proxy
    @ui.proxy_thread.join
    assert_match(PROXY_RUNNING, @ui.message)
    assert_empty(@p.requests)
  end

  def test_one_request
    def @ui.ask(q)
      "f"
    end

    p, p_port = start_proxy
    ws, ws_port = start_basic_webrick
    r = Turf::get("http://127.0.0.1:#{ws_port}/")
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    p.join
    ws.terminate
    assert_equal(1, @p.requests.length)
  end

  def test_mitm_ssl
    p, p_port = start_proxy
    ws, ws_port = start_tls_webrick

    r = Turf::get("https://127.0.0.1:#{ws_port}/")
    r.run proxy: "http://127.0.0.1:#{p_port}"

    p.raise IRB::Abort
    p.join
    ws.terminate
    assert_equal(2, @p.requests.length)
  end

  def test_continue
    def @ui.ask(q)
      "c"
    end

    def @ui.info(s, from: nil)
      # Need to raise second abort once the first one
      # has been processed.
      if s.include?("Use Ctrl-C one more time to quit")
        @proxy_thread.raise IRB::Abort
      end
    end

    p, p_port = start_proxy
    ws, ws_port = start_basic_webrick
    r = Turf::get("http://127.0.0.1:#{ws_port}/")
    r.run proxy: "http://127.0.0.1:#{p_port}"
    assert_equal("200", r.response.status)

    p.raise IRB::Abort
    p.join
    ws.terminate
    assert_equal(1, @p.requests.length)
  end

  def test_drop
    def @ui.ask(q)
      "d"
    end

    p, p_port = start_proxy
    ws, ws_port = start_basic_webrick
    r = Turf::get("http://127.0.0.1:#{ws_port}/")

    assert_raises(EOFError) {
      r.run proxy: "http://127.0.0.1:#{p_port}"
    }

    p.raise IRB::Abort
    p.join
    ws.terminate
    assert_equal(1, @p.requests.length)
    assert_nil(@p.requests[0].response)
  end
end
