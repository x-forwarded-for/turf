require 'irb'
require 'socket'

module Turf

  class ProxyThread

    attr_accessor :request
    attr_accessor :client
    attr_accessor :proxy
    attr_accessor :close_connection

    def initialize(proxy, client)
      @proxy = proxy
      @client = client
      @close_connection = true
      handle_one_request
    end

    def handle_one_request
      read_request
      puts @request.inspect
      interact_request

      @request.run
      puts "Done running request"

      puts @request.response.inspect
      interact_response
      write_response
    end

    def read_request
      @request = Request.new client
    end

    def write_response
      @client.write @request.response
    end

    def interact_request
      loop do
        puts '[f]orward, (v)iew ?'
        action = gets.chomp
        case action
        when 'v'
          puts @request.to_s
        when '', 'f'
          break
        end
      end
    end

    def interact_response
    end

  end

  class Proxy

    attr_accessor :hostname
    attr_accessor :port
    attr_accessor :rules
    attr_accessor :persistent
    attr_accessor :verbose

    def initialize(hostname: nil, port: nil)
      @hostname = hostname || "127.0.0.1"
      @port = port || 8080
    end

    def start_sync
      server = TCPServer.new @hostname, @port
      server.setsockopt(:SOCKET, :REUSEADDR, true)
      Thread.abort_on_exception = true
      begin
        loop do
          Thread.new(server.accept) do |client|
            ProxyThread.new(self, client)
          end
        end
      rescue IRB::Abort # IRB translation for SIGINT
        server.shutdown
      end
    end

  end

  module_function

  def proxy
    p = Proxy.new
    p.start_sync
  end
end
