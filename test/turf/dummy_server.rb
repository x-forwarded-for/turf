require 'webrick'
require 'webrick/https'

module DummyServer

  def wait_until_online(host, port)
    loop do
      begin
        s = TCPSocket.new host, port
        s.close
        break
      rescue Errno::ECONNREFUSED
      end
    end
  end

  def start_basic_webrick
    port = rand(1025..65535)
    ws = Thread.new {
      server = WEBrick::HTTPServer.new(:Port => port, :AccessLog => [],
                :Logger => WEBrick::Log::new("/dev/null", 7))
      server.mount_proc '/' do |req, res|
        res["Content-Type"] = "text/plain"
        res.body = 'Hello, world!'
        if req.body and req.body.include? "def12"
          res.status = "500"
        end
      end
      server.start
    }
    return ws, port
  end

  def start_tls_webrick
    port = rand(1025..65535)
    ws = Thread.new {
      cert_name = [ %w[CN localhost], ]
      server = WEBrick::HTTPServer.new(:Port => port, :AccessLog => [],
                :Logger => WEBrick::Log::new("/dev/null", 7),
                :SSLEnable => true, :SSLCertName => cert_name)
      server.mount_proc '/' do |req, res|
        res.body = 'Hello, world!'
      end
      server.start
    }
    return ws, port
  end

end
