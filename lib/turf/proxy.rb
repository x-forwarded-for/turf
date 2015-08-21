require "irb"
require "monitor"
require "socket"
require "readline"

module Turf

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

class Turf::Proxy

  require_relative "proxy/proxy_thread"
  require_relative "proxy/console_ui"

  attr_reader :port
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
    @requests = Turf::RequestArray.new
    @requests_lock = Mutex.new
    @ca = Turf::CertificateAuthority.new
    @continue = false
    @ui = ui || ConsoleUI.new
  end

  def bind
    @server = TCPServer.new @hostname, @port
    if @port.zero?
      @port = @server.addr[1]
    end
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
        rescue Interrupt
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
    rescue Interrupt
      @server.shutdown
      threads.each(&:terminate)
    end
  end
end
