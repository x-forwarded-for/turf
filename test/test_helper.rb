require "minitest/autorun"
require "minitest/hell"

require "thread"
require "webrick"
require "webrick/https"
require "stringio"

require "turf"

temp_dir = Dir.mktmpdir
Turf.set_conf_path temp_dir
Minitest.after_run { FileUtils.remove_entry_secure temp_dir }

def start_basic_webrick
  mutex = Mutex.new
  condition = ConditionVariable.new

  server = WEBrick::HTTPServer.new(
    Port: 0,
    AccessLog: [],
    Logger: WEBrick::Log.new("/dev/stderr", 1),
    BindAddress: "127.0.0.1",
    StartCallback: Proc.new do
      mutex.synchronize { condition.signal }
    end
  )
  server.mount_proc "/" do |req, res|
    res["Content-Type"] = "text/plain"
    res.body = "Hello, world!"
    if req.body and req.body.include? "def12"
      res.status = "500"
    end
  end

  webrick_thread = Thread.new do
    begin
      server.start
    rescue Exception => e
      puts e.inspect
      puts e
    end
  end

  mutex.synchronize { condition.wait(mutex) }
  return webrick_thread, server.config[:Port]
end

def start_tls_webrick
  mutex = Mutex.new
  condition = ConditionVariable.new

  cert_name = [ %w[CN localhost], ]

  # unfortunately needed because webrick's ssl.rb has $stderr.putc
  orig_stderr = $stderr
  $stderr = StringIO.new

  begin
    server = WEBrick::HTTPServer.new(
      Port: 0,
      AccessLog: [],
      Logger: WEBrick::Log.new("/dev/stderr", 1),
      SSLEnable: true,
      SSLCertName: cert_name,
      BindAddress: "127.0.0.1",
      StartCallback: Proc.new do
        mutex.synchronize { condition.signal }
      end
    )
  ensure
    $stderr = orig_stderr
  end

  server.mount_proc "/" do |req, res|
    res.body = "Hello, world!"
  end

  webrick_thread = Thread.new do
    begin
      server.start
    rescue Exception => e
      puts e.inspect
      puts e
    end
  end

  mutex.synchronize { condition.wait(mutex) }
  return webrick_thread, server.config[:Port]
end
