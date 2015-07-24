require 'minitest/autorun'
require 'minitest/hell'

require 'thread'
require 'webrick'
require 'webrick/https'
require 'stringio'

require 'turf'

temp_dir = Dir.mktmpdir
Turf.set_conf_path temp_dir
Minitest.after_run { FileUtils.remove_entry_secure temp_dir }

def start_basic_webrick
  m = Mutex.new
  c = ConditionVariable.new
  port = rand(1025..65535)

  m.synchronize {
    ws = Thread.new {
      begin
        server = WEBrick::HTTPServer.new(
          Port: port,
          AccessLog: [],
          Logger: WEBrick::Log::new("/dev/stderr", 1),
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
      rescue Exception => e
        puts e.inspect
        puts e
      end
    }
    c.wait(m)
    return ws, port
  }
end

def start_tls_webrick
  m = Mutex.new
  c = ConditionVariable.new
  port = rand(1025..65535)

  m.synchronize {
    ws = Thread.new {
      begin
        cert_name = [ %w[CN localhost], ]
        # unfortunately needed because webrick's ssl.rb has $stderr.putc
        orig_stderr = $stderr
        $stderr = StringIO.new
        server = WEBrick::HTTPServer.new(
          Port: port,
          AccessLog: [],
          Logger: WEBrick::Log::new("/dev/stderr", 1),
          SSLEnable: true,
          SSLCertName: cert_name,
          BindAddress: '127.0.0.1',
          StartCallback: Proc.new do
            m.synchronize { c.signal }
          end
        )
        $stderr = orig_stderr
        server.mount_proc '/' do |req, res|
          res.body = 'Hello, world!'
        end
        server.start
      rescue Exception => e
        puts e.inspect
        puts e
      end
    }
    c.wait(m)
    return ws, port
  }
end
