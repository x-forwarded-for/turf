require 'simplecov'
SimpleCov.start do
  add_filter "/test/"
end

require 'minitest/autorun'
require 'minitest/hell'

require_relative '../lib/turf'

require 'webrick'
require 'webrick/https'

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
  #FIXME - need to close these (or start using condvars)
  reader, writer = IO.pipe

  port = rand(1025..65535)
  ws = Thread.new {
    server = WEBrick::HTTPServer.new(
      Port: port,
      AccessLog: [],
      Logger: WEBrick::Log::new("/dev/null", 7),
      BindAddress: '127.0.0.1',
      StartCallback: Proc.new {
        writer.write("1")
      }
    )
    server.mount_proc '/' do |req, res|
      res["Content-Type"] = "text/plain"
      res.body = 'Hello, world!'
      if req.body and req.body.include? "def12"
        res.status = "500"
      end
    end
    server.start
  }
  reader.read(1)
  return ws, port
end

def start_tls_webrick
  #FIXME - need to close these (or start using condvars)
  reader, writer = IO.pipe

  port = rand(1025..65535)
  ws = Thread.new {
    cert_name = [ %w[CN localhost], ]
    server = WEBrick::HTTPServer.new(
      Port: port,
      AccessLog: [],
      Logger: WEBrick::Log::new("/dev/null", 7),
      SSLEnable: true,
      SSLCertName: cert_name,
      BindAddress: '127.0.0.1',
      StartCallback: Proc.new {
        writer.write("1")
      }
    )
    server.mount_proc '/' do |req, res|
      res.body = 'Hello, world!'
    end
    server.start
  }
  reader.read(1)
  return ws, port
end
