module Turf
  class Proxy::ProxyThread

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
      @request = Request.new @client, hostname: hostname,
                             port: port, use_ssl: true
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
        @proxy.ui.info @request.headers_array.to_a.to_s
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
      interact_response unless @proxy.continue
      write_response
    end

    def read_request
      if @request and @request.use_ssl
        @request = Request.new client, hostname: @request.hostname,
                               port: @request.port, use_ssl: true
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
          question = "[m]itm, (c)ontinue, (d)rop, (v)iew, (h)eaders ? "
        else
          question = "[f]orward, (c)ontinue, (d)rop, (v)iew, (h)eaders ? "
        end
        a = @proxy.ui.ask(question)
        a = a.empty? ? (is_connect? ? "m" : "f") : a
        if am.include?(a)
          return am[a]
        end
      end
    end

    def interact_response
      action_map = {"c" => :continue, "v" => :view,
                    "d" => :drop, "h" => :view_headers }
      action_map = action_map.merge({ "f" => :forward})
      loop do
        a = @proxy.ui.ask "[f]orward, (c)ontinue, (d)rop, (v)iew, (h)eaders ? "
        a = a.empty? ? "f" : a
        if action_map.include?(a)
          return action_map[a]
        end
      end
    end

  end
end
