require_relative "../test_helper"

require "net/http"

class ProxyTest < MiniTest::Test

  class DummyUI

    attr_reader :errors
    attr_reader :infos

    def initialize
      @errors = []
      @infos = []
    end

    def info(message, from: nil)
      @infos << message
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
  end

  def start_proxy
    proxy = Turf::Proxy.new(port: 0, ui: @ui)
    mutex = Mutex.new
    proxy_started = ConditionVariable.new
    proxy_thread = nil
    mutex.synchronize do
      proxy_thread = Thread.new do
        Thread.current.abort_on_exception = true
        mutex.synchronize do
          proxy.bind
          proxy_started.signal
        end
        proxy.serve
      end
      proxy_started.wait(mutex)
    end
    return { thread: proxy_thread,
      proxy: proxy,
      port: proxy.port,
    }
  end

  def test_irb_stop_after_start
    def @ui.info(message, from: nil)
      super
      raise Interrupt
    end

    p = start_proxy
    p[:thread].join
    assert_includes(@ui.infos, "Running on 127.0.0.1:#{p[:port]}")
    assert_empty(p[:proxy].requests)
  end

  def test_one_request
    def @ui.ask(q)
      "f"
    end

    p = start_proxy
    ws, ws_port = start_basic_webrick

    r = Turf.get("http://127.0.0.1:#{ws_port}/")
    r.run(proxy: "http://127.0.0.1:#{p[:port]}")

    p[:thread].raise Interrupt
    p[:thread].join
    ws.terminate
    assert_equal(1, p[:proxy].requests.length)
  end

  def test_mitm_ssl
    p = start_proxy
    ws, ws_port = start_tls_webrick

    r = Turf.get("https://127.0.0.1:#{ws_port}/")
    r.run(proxy: "http://127.0.0.1:#{p[:port]}")

    p[:thread].raise Interrupt.new
    p[:thread].join
    ws.terminate
    assert_equal(2, p[:proxy].requests.length)
  end

  def test_continue
    def @ui.ask(q)
      "c"
    end

    def @ui.info(message, from: nil)
      super
      # Need to raise second abort once the first one
      # has been processed.
      if message.include?("Use Ctrl-C one more time to quit")
        raise Interrupt
      end
    end

    p = start_proxy
    ws, ws_port = start_basic_webrick

    r = Turf.get("http://127.0.0.1:#{ws_port}/")
    r.run(proxy: "http://127.0.0.1:#{p[:port]}")
    assert_equal("200", r.response.status)

    p[:thread].raise Interrupt
    p[:thread].join
    ws.terminate
    assert_equal(1, p[:proxy].requests.length)
  end

  def test_drop
    def @ui.ask(q)
      "d"
    end

    p = start_proxy
    ws, ws_port = start_basic_webrick

    r = Turf::get("http://127.0.0.1:#{ws_port}/")

    assert_raises(EOFError) {
      r.run(proxy: "http://127.0.0.1:#{p[:port]}")
    }

    p[:thread].raise Interrupt
    p[:thread].join
    ws.terminate

    assert_equal(1, p[:proxy].requests.length)
    assert_nil(p[:proxy].requests[0].response)
  end

  def test_cert_rejected_followed_by_not_rejected
    p = start_proxy
    ws, ws_port = start_tls_webrick

    uri = URI.parse("https://127.0.0.1:#{ws_port}/")
    req = Net::HTTP::Get.new(uri.request_uri)
    con = Net::HTTP.new(uri.host, uri.port, "127.0.0.1", p[:port])
    con.use_ssl = true

    ex = assert_raises(OpenSSL::SSL::SSLError) do
      res = con.request(req)
    end
    assert_includes(ex.message, "certificate verify failed")

    con.verify_mode = OpenSSL::SSL::VERIFY_NONE
    res2 = con.request(req)

    p[:thread].raise Interrupt.new
    p[:thread].join
    ws.terminate
    assert_equal(3, p[:proxy].requests.length)
    assert_equal("CONNECT", p[:proxy].requests[0].method)
    assert_equal("CONNECT", p[:proxy].requests[1].method)
    assert_equal("GET", p[:proxy].requests[2].method)
    assert_equal(2, @ui.errors.size)
    assert_includes(@ui.errors, "The certificate has been rejected by your client.")
    assert(@ui.errors.any? { |error| error.include? "unknown ca" })
  end

end
