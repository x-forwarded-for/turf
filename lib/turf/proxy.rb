require 'irb'
require 'monitor'
require 'socket'
require 'readline'

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
        rescue OpenSSL::SSL::SSLError => e
          @proxy.ui.error e.inspect
          if e.to_s.include? "alert unknown ca"
            @proxy.ui.error "The certificate has been rejected by your client."
          end
          break
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
        @proxy.ui.info @request.to_s
      when :view_headers
        @proxy.ui.info @request.headers.to_s
      when :mitm_ssl
        mitm_ssl(@request.hostname, @request.port)
        @action = request_prologue
      when :continue
        @proxy.continue = true
        @action = default_action
        perform_action
        @proxy.ui.info @request.inspect
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
        @proxy.ui.info @request.inspect
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

      @proxy.ui.info @request.response.inspect
      interact_response
      write_response
    end

    def read_request
      if @request and @request.use_ssl
        @request = Request.new client, :hostname => @request.hostname,
                          :port => @request.port, :use_ssl => true
      else
        @request = Request.new client
      end
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
          question = '[m]itm, (c)ontinue, (d)rop, (v)iew, (h)eaders ? '
        else
          question = '[f]orward, (c)ontinue, (d)rop, (v)iew, (h)eaders ? '
        end
        a = @proxy.ui.ask(question)
        a = a.empty? ? (is_connect? ? "m" : "f") : a
        if am.include?(a)
          return am[a]
        end
      end
    end

    def interact_response
    end

  end

  class ConsoleUI

    def initialize
      @lock = Monitor.new
    end

    def info(s, from: nil)
      @lock.synchronize {
        puts with_from(s, from: from)
      }
    end

    def ask(question)
      @lock.synchronize {
        Readline.readline(with_from(question), false).squeeze(" ").strip
      }
    end

    def error(s, from: nil)
      @lock.synchronize {
        puts with_from(s.red, from: from)
      }
    end

    private

    def with_from(s, from: nil)
      from ||= Thread.current["id"]
      "[#{from}] #{s}"
    end

  end

  class Proxy

    attr_accessor :rules
    attr_accessor :requests
    attr_accessor :requests_lock
    attr_accessor :ca
    attr_accessor :continue
    attr_accessor :ui

    def initialize(hostname: nil, port: nil, ui: nil)
      @hostname = hostname || "127.0.0.1"
      @port = port || 8080
      @rules = nil
      @requests = RequestArray.new
      @requests_lock = Mutex.new
      @ca = CertificateAuthority.new
      @continue = false
      @ui = ui || ConsoleUI.new
    end

    def bind
      @server = TCPServer.new @hostname, @port
      @server.setsockopt(:SOCKET, :REUSEADDR, true)
    end

    def serve
      threads = Array.new
      begin
        @ui.info "Running on #{@hostname}:#{@port}", from: "main"
        id = 0
        loop do
          begin
            threads << Thread.new(@server.accept, id) do |client, id|
              begin
                Thread.current["id"] = id
                ProxyThread.new(self, client)
              rescue Exception => e
                @ui.info "Proxy threads died with:"
                @ui.info e.inspect
                @ui.info e
              end
            end
            rescue IRB::Abort
              if @continue
                @continue = false
                @ui.info "Manual mode", from: "main"
                @ui.info "Use Ctrl-C one more time to quit", from: "main"
              else
                raise
              end
          end
          id += 1
        end
      rescue IRB::Abort # IRB translation for SIGINT
        @server.shutdown
        threads.each { |t| t.terminate }
      end
    end

  end

  module_function

  # Starts a regular proxy on the default interface and port.
  # Use Ctrl-C to terminate the proxy.
  # See Proxy.new for possible arguments
  #
  # Returns a RequestArray of all the requests processed.
  #
  # Example:
  #     ra = proxy
  #
  def proxy(args = {})
    p = Proxy.new args
    p.bind
    p.serve
    return p.requests
  end

  # Starts an automated proxy which will use default actions
  # for all requests (HTTP => forward, HTTPS => man-in-the-middle)
  # See Proxy.new for possible arguments
  #
  # Returns a RequestArray of all the requests processed.
  #
  # Example:
  #     ra = forwarder
  #
  def forwarder(args = {})
    p = Proxy.new args
    p.continue = true
    p.bind
    p.serve
    return p.requests
  end

end
