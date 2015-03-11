require_relative '../test_helper'

require 'webrick'

class ProxyTest < MiniTest::Test

  def wait_until_online(host, port)
    loop do
      begin
        s = TCPSocket.new host, port
        break if s
      rescue Errno::ECONNREFUSED
      end
    end
  end

  def test_new
    p  = Thread.new {
      rs = Turf::proxy :rules => [[ proc {|x| true}, :forward ]]
      puts rs.inspect
    }
    ws = Thread.new {
      server = WEBrick::HTTPServer.new :Port => 8000
      server.mount_proc '/' do |req, res|
        res.body = 'Hello, world!'
      end
      server.start
    }
    wait_until_online '127.0.0.1', 8000
    wait_until_online '127.0.0.1', 8080

    r = Turf::Request.new("GET / HTTP/1.1\r\n\r\n", hostname: "127.0.0.1",
                          port: 8000, use_ssl: false)
    r.run proxy: "http://127.0.0.1:8080"

    p.raise IRB::Abort
    ws.terminate
  end

end
