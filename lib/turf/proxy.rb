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
      @close_connection = false
      loop do
        begin
          handle_one_request
        rescue EOFError
          @close_connection = true
        end
        break if @close_connection
      end
      @client.close
    end

    def mitm_ssl(hostname, port)
      @client.write "HTTP/1.1 200 Connection established\r\n\r\n"
      context = OpenSSL::SSL::SSLContext.new
      context.cert = @proxy.ca.certificate(hostname)
      context.key = @proxy.ca.key
      @client = OpenSSL::SSL::SSLSocket.new @client, context
      @client.accept
      @request = Request.new @client, :hostname => hostname,
                          :port => port, :use_ssl => true
    end

    def apply_rules
      @proxy.rules.each do |rule, action|
         return action if rule.call(@request)
      end
    end

    def terminal_action?(action)
      [:forward, :drop].include? action
    end

    def perform_action(action)
      case action
      when :view
        puts @request.to_s
      when :view_headers
        puts @request.headers.to_s
      when :mitm_ssl
        mitm_ssl(@request.hostname, @request.port)
      end
    end

    def request_prologue
      @proxy.requests_lock.synchronize {
        @proxy.requests << @request
      }
      action = @proxy.rules ? apply_rules : nil
      return action
    end

    def handle_one_request
      read_request
      action = request_prologue
      loop do
        puts @request.inspect
        unless action
          action = interact_request
        end
        perform_action action
        if action == :mitm_ssl
          action = request_prologue
          next
        end
        break if terminal_action? action
        action = nil
      end
      if action == :drop
        @close_connection = true
        return
      end

      @request.run

      puts @request.response.inspect
      interact_response
      write_response
    end

    def read_request
      @request = Request.new client
    end

    def write_response
      @client.write @request.response.to_s
    end

    def interact_request
      action_map = { "f" => :forward, "v" => :view, "d" => :drop,
                     "h" => :view_headers, "m" => :mitm_ssl }
      loop do
        puts '[f]orward, (d)rop, (v)iew, (h)eaders  ?'
        a = gets.chomp
        a = a.empty? ? "f" : a
        if action_map.include?(a)
          return action_map[a]
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
    attr_accessor :requests
    attr_accessor :requests_lock
    attr_accessor :ca

    def initialize(hostname: nil, port: nil, rules: nil)
      @hostname = hostname || "127.0.0.1"
      @port = port || 8080
      @rules = rules
      @requests = RequestArray.new
      @requests_lock = Mutex.new
      @ca = CertificateAuthority.new
    end

    def start_sync
      server = TCPServer.new @hostname, @port
      server.setsockopt(:SOCKET, :REUSEADDR, true)
      puts "Running on #{@hostname}:#{@port}"
      threads = Array.new
      begin
        loop do
          threads << Thread.new(server.accept) do |client|
            ProxyThread.new(self, client)
          end
        end
      rescue IRB::Abort # IRB translation for SIGINT
        server.shutdown
        threads.each { |t| t.terminate }
      end
    end

  end

  module_function

  def proxy(*args)
    p = Proxy.new *args
    p.start_sync
    return p.requests
  end

end
