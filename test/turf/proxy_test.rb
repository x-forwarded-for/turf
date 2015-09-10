require_relative "../test_helper"

require "net/http"

class ProxyTest < MiniTest::Test

  PROXY_RUNNING = /\ARunning on (.*):(?<proxy_port>[0-9]+)\z/

  class DummyUI

    attr_accessor :proxy_thread
    attr_accessor :message
    attr_reader :errors

    def initialize
      @errors = []
    end

    def info(s, from: nil)
    end

    def ask(q)
      ""
    end

    def error(error_message)
      @errors << error_message
    end

  end

  def setup
    @ui = DummyUI.new
    @m = Mutex.new
    @started = ConditionVariable.new
  end

  def start_proxy
    @m.synchronize {
      t = Thread.new do
        @m.synchronize {
          @p = Turf::Proxy.new(port: 0, ui: @ui)
          @p.bind
          @started.signal
        }
        @p.serve
      end
      @ui.proxy_thread = t
      @started.wait(@m)
      return t, @p.port
    }
  end

  def test_irb_stop_after_start
    def @ui.info(message, from: nil)
      @message = message
      @proxy_thread.raise Interrupt
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

    r = Turf.get("http://127.0.0.1:#{ws_port}/")
    r.run(proxy: "http://127.0.0.1:#{p_port}")

    p.raise Interrupt
    p.join
    ws.terminate
    assert_equal(1, @p.requests.length)
  end

  def test_mitm_ssl
    p, p_port = start_proxy
    ws, ws_port = start_tls_webrick

    r = Turf.get("https://127.0.0.1:#{ws_port}/")
    r.run(proxy: "http://127.0.0.1:#{p_port}")

    p.raise Interrupt.new
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
        @proxy_thread.raise Interrupt
      end
    end

    p, p_port = start_proxy
    ws, ws_port = start_basic_webrick

    r = Turf.get("http://127.0.0.1:#{ws_port}/")
    r.run(proxy: "http://127.0.0.1:#{p_port}")
    assert_equal("200", r.response.status)

    p.raise Interrupt
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
      r.run(proxy: "http://127.0.0.1:#{p_port}")
    }

    p.raise Interrupt
    p.join
    ws.terminate

    assert_equal(1, @p.requests.length)
    assert_nil(@p.requests[0].response)
  end

  def test_cert_rejected_followed_by_not_rejected
    p, p_port = start_proxy
    ws, ws_port = start_tls_webrick

    uri = URI.parse("https://127.0.0.1:#{ws_port}/")
    req = Net::HTTP::Get.new(uri.request_uri)
    con = Net::HTTP.new(uri.host, uri.port, "127.0.0.1", p_port)
    con.use_ssl = true

    ex = assert_raises(OpenSSL::SSL::SSLError) do
      res = con.request(req)
    end
    assert_includes(ex.message, "certificate verify failed")

    con.verify_mode = OpenSSL::SSL::VERIFY_NONE
    res2 = con.request(req)

    p.raise Interrupt.new
    p.join
    ws.terminate
    assert_equal(3, @p.requests.length)
    assert_equal("CONNECT", @p.requests[0].method)
    assert_equal("CONNECT", @p.requests[1].method)
    assert_equal("GET", @p.requests[2].method)
    assert_equal(2, @ui.errors.size)
    assert_includes(@ui.errors, "The certificate has been rejected by your client.")
    assert(@ui.errors.any? { |error| error.include? "unknown ca" })
  end

end
