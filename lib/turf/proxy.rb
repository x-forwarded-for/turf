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
      @proxy.rules.call(@request)
    end

    def is_connect?
      @request.method == "CONNECT"
    end

    def default_action
      (is_connect? ? :mitm_ssl : :forward)
    end

    def terminal_action?
      [:forward, :drop].include?(@action) or @proxy.continue
    end

    def perform_action
      case @action
      when :view
        puts @request.to_s
      when :view_headers
        puts @request.headers.to_s
      when :mitm_ssl
        mitm_ssl(@request.hostname, @request.port)
        @action = request_prologue
      when :continue
        @proxy.continue = true
        @action = default_action
        perform_action
        puts @request.inspect
      end
    end

    def request_prologue
      @proxy.requests_lock.synchronize {
        @proxy.requests << @request
      }
      @action = @proxy.rules ? apply_rules : nil
    end

    def handle_one_request
      read_request
      request_prologue
      loop do
        puts @request.inspect
        unless @action
          if @proxy.continue
            @action = default_action
          else
            @action = interact_request
          end
        end
        perform_action
        next if @action == :mitm_ssl
        if @action == :drop
          @close_connection = true
          return
        end
        break if terminal_action?
        @action = nil
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
      action_map = {"c" => :continue, "v" => :view,
                    "d" => :drop, "h" => :view_headers }
      action_map_http  = action_map.merge({ "f" => :forward })
      action_map_https = action_map.merge({ "m" => :mitm_ssl })
      am = is_connect? ? action_map_https : action_map_http
      loop do
        if is_connect?
          puts '[m]itm, (c)ontinue, (d)rop, (v)iew, (h)eaders ?'
        else
          puts '[f]orward, (c)ontinue, (d)rop, (v)iew, (h)eaders ?'
        end
        a = gets.chomp
        a = a.empty? ? (is_connect? ? "m" : "f") : a
        if am.include?(a)
          return am[a]
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
    attr_accessor :requests
    attr_accessor :requests_lock
    attr_accessor :ca
    attr_accessor :continue

    def initialize(hostname: nil, port: nil, &block)
      @hostname = hostname || "127.0.0.1"
      @port = port || 8080
      @rules = block
      @requests = RequestArray.new
      @requests_lock = Mutex.new
      @ca = CertificateAuthority.new
      @continue = false
    end

    def start_sync
      server = TCPServer.new @hostname, @port
      server.setsockopt(:SOCKET, :REUSEADDR, true)
      puts "Running on #{@hostname}:#{@port}"
      threads = Array.new
      begin
        loop do
          begin
            threads << Thread.new(server.accept) do |client|
              ProxyThread.new(self, client)
            end
            rescue IRB::Abort
              if @continue
                @continue = false
                puts "Manual mode"
                puts "Use Ctrl-C one more time to quit"
              else
                raise
              end
          end
        end
      rescue IRB::Abort # IRB translation for SIGINT
        server.shutdown
        threads.each { |t| t.terminate }
      end
    end

  end

  module_function

  def proxy(hostname: nil, port: nil, &block)
    p = Proxy.new :hostname => hostname, :port => port, &block
    p.start_sync
    return p.requests
  end

end
