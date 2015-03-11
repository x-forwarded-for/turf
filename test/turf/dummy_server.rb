require 'webrick'
require 'webrick/https'

module DummyServer

  def wait_until_online(host, port)
    loop do
      begin
        s = TCPSocket.new host, port
        break if s
      rescue Errno::ECONNREFUSED
      end
    end
  end

  def start_basic_webrick
    Thread.new {
      server = WEBrick::HTTPServer.new(:Port => 8000, :AccessLog => [],
                :Logger => WEBrick::Log::new("/dev/null", 7))
      server.mount_proc '/' do |req, res|
        res.body = 'Hello, world!'
      end
      server.start
    }
  end

  def start_tls_webrick
    Thread.new {
      cert_name = [ %w[CN localhost], ]
      server = WEBrick::HTTPServer.new(:Port => 8001, :AccessLog => [],
                :Logger => WEBrick::Log::new("/dev/null", 7),
                :SSLEnable => true, :SSLCertName => cert_name)
      server.mount_proc '/' do |req, res|
        res.body = 'Hello, world!'
      end
      server.start
    }
  end

end
