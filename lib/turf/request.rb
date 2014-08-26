require 'uri'

module Turf

  class Request

      include Turf::Message

      attr_accessor :hostname
      attr_accessor :port
      attr_accessor :use_ssl

      attr_accessor :method
      attr_accessor :url
      attr_accessor :http_version

      attr_accessor :raw_headers
      attr_accessor :raw_content

      attr_accessor :response

      def initialize(io, hostname: nil, port: nil, use_ssl: false)
        io = StringIO.new(io) if io.is_a? String
        start_line = read_start_line(io)
        @method, url, @http_version = start_line
        if @method == "CONNECT"
          raise Exception.new "To Implement"
        elsif hostname
          @hostname = hostname
          @port = port ? port.to_i : (use_ssl ? 80 : 443)
          @use_ssl = use_ssl
          @url = url
        else
          p_url = URI(url)
          raise Exception.new("No scheme!") if not p_url.scheme
          @url = URI::Generic.new(*([nil] * 4 + URI.split(url)[4..-1])).to_s
          @hostname = p_url.host
          if p_url.scheme == 'https'
            @use_ssl = true
            @port = port ? port.to_i : 443
          else
            @use_ssl = false
            @port = port ? port.to_i : 80
          end
        end
        @raw_headers = read_headers(io)
        @raw_content = read_content(io, headers, method: @method)
        @response = nil
      end

      def headers
          parse_headers(@raw_headers)
      end

      def connect
        super @hostname, @port, @use_ssl
      end

      def run(sock = nil, chunk_cb: nil)
        sock ||= connect
        History.instance << self
        send_all(sock, to_s)
        @response = read_response(sock)
      end

      def read_response(sock)
        Response.new(sock, self, chunk_cb: nil)
      end

      def to_s
        start_line = [@method, @url, @http_version].join(" ")
        data = [start_line, @raw_headers, ""].join("\r\n")
        data << @raw_content
        return data
      end

      def inspect
        '<' + [@method, @hostname, @url].join(" ") + '>'
      end

      def initialize_copy(source)
        super
        @response = nil
      end

      def *(n)
        RequestArray.new (1..n).to_a.map { |x| self.clone }
      end

  end

end
