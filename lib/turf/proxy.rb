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
      end
    end

    def handle_one_request
      read_request
      action = @proxy.rules ? apply_rules : nil
      loop do
        puts @request.inspect
        unless action
          action = interact_request
        end
        perform_action action
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
      @client.write @request.response
    end

    def interact_request
      action_map = { "f" => :forward, "v" => :view, "d" => :drop,
                     "h" => :view_headers }
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

    def initialize(hostname: nil, port: nil, rules: nil)
      @hostname = hostname || "127.0.0.1"
      @port = port || 8080
      @rules = rules
    end

    def start_sync
      server = TCPServer.new @hostname, @port
      server.setsockopt(:SOCKET, :REUSEADDR, true)
      Thread.abort_on_exception = true
      puts "Running on #{@hostname}:#{@port}"
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

  def proxy(*args)
    p = Proxy.new *args
    p.start_sync
  end

end
