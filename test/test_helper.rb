require 'minitest/autorun'
require 'minitest/hell'

require 'thread'
require 'webrick'
require 'webrick/https'

require_relative '../lib/turf'

def start_basic_webrick
  m = Mutex.new
  c = ConditionVariable.new
  port = rand(1025..65535)

  ws = Thread.new {
    abort_on_exception = true
    server = WEBrick::HTTPServer.new(
      Port: port,
      AccessLog: [],
      Logger: WEBrick::Log::new("/dev/null", 7),
      BindAddress: '127.0.0.1',
      StartCallback: Proc.new do
        m.synchronize { c.signal }
      end
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
  m.synchronize {
    c.wait(m)
  }
  return ws, port
end

def start_tls_webrick
  m = Mutex.new
  c = ConditionVariable.new
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
      StartCallback: Proc.new do
        m.synchronize { c.signal }
      end
    )
    server.mount_proc '/' do |req, res|
      res.body = 'Hello, world!'
    end
    server.start
  }
  m.synchronize {
    c.wait(m)
  }
  return ws, port
end
