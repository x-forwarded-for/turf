module Turf
  class Proxy::ProxyThread

    attr_accessor :request
    attr_accessor :client
    attr_accessor :proxy

    def initialize(proxy, client)
      @proxy = proxy
      @client = client
      catch(:close_connection) do
        loop do
          begin
            handle_one_request
          rescue EOFError
            throw(:close_connection)
          rescue OpenSSL::SSL::SSLError => e
            @proxy.ui.error e.inspect
            if e.to_s.include? "alert unknown ca"
              @proxy.ui.error "The certificate has been rejected by your client."
            end
            throw(:close_connection)
          end
        end
      end
      @client.close
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

    def request_prologue
      @proxy.requests_lock.synchronize {
        @proxy.requests << @request
      }
      @action = @proxy.rules ? apply_rules : nil
    end

    def handle_one_request
      read_request
      request_prologue

      # TODO: - replace this with some form of "run all plugins for requests"
      Proxy::RequestPlugin::ManualInteraction.run(proxy, self)

      @request.run

      loop do
        @proxy.ui.info @request.response.inspect
        action = interact_response unless @proxy.continue
        if action == :view
          @proxy.ui.info @request.response.to_s
        else
          break
        end
      end
      write_response
    end

    def read_request
      if @request and @request.use_ssl
        @request = Request.new client, hostname: @request.hostname,
                                       port: @request.port,
                                       use_ssl: true
      else
        @request = Request.new client
      end
    end

    def write_response
      @client.write @request.response.to_s
    end

    def interact_response
      action_map = { "c" => :continue, "v" => :view,
                     "d" => :drop, "h" => :view_headers }
      action_map = action_map.merge({ "f" => :forward })
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
