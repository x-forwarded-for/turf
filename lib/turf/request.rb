require 'uri'
require 'colorize'

##
# Represents an HTTP request.
#
# This is the basic class for Turf. Direct instanciation will rarely occur.
# One may use the Turf.get and Turf.post aliases to create a Request from
# an URL.
#
# When the request is sent, only the basic attributes are used. This is what
# is exactly sent on the socket for every request:
#
#   <method> space <url> space <http_version> \r\n
#   <raw_headers> \r\n
#   \r\n
#   <raw_content>
#
# All the other attributes are higher level abstractions that will be generated
# from these primitive attributes.
#
# See also Turf::Response and Turf::RequestArray
class Turf::Request

  include Turf::Message

  # Hostname or IP address e.g., "example.org, "127.0.0.1"
  attr_accessor :hostname
  # Port, must be an integer e.g., 8000, 443
  attr_accessor :port
  # Boolean to describe if the request uses SSL/TLS
  attr_accessor :use_ssl

  # Method or HTTP verb e.g., GET, POST
  attr_accessor :method
  # URL e.g., "/index.html?param=abc"
  # May include the hostname when using the CONNECT method
  attr_accessor :url
  # HTTP version with prefix e.g., "HTTP/1.1"
  attr_accessor :http_version

  # Raw headers represented as a String
  attr_accessor :raw_headers
  # Raw content represented as a String
  attr_accessor :raw_content

  # A reference to the associated Turf::Response. May be nil if the
  # Request has not been run yet
  attr_accessor :response

  ##
  # Create a new Request
  #
  # +io+ must be a IO-like object from which the Request is read.
  # If +hostname+ is not provided, it will be read from +io+.
  # If +port+ is not provided, it will be deduce from the URL scheme.
  # If +use_ssl+ is not provided, it will be deduce from +port+.
  #
  def initialize(io, hostname: nil, port: nil, use_ssl: false)
    io = StringIO.new(io) if io.is_a? String
    start_line = read_start_line(io)
    @method, url, @http_version = start_line
    if /\ACONNECT\z/i =~ @method
      @hostname, port = url.split(":", 2)
      @port = port.to_i
      @use_ssl = false
      @url = ""
    elsif hostname
      @hostname = hostname
      @port = port ? port.to_i : (use_ssl ? 443 : 80)
      @use_ssl = use_ssl ? use_ssl : (@port == 443 ? true : false)
      @url = url
    else
      p_url = URI(url)
      raise Exception.new("No scheme: #{p_url}") if not p_url.scheme
      @url = URI::Generic.new(*([nil] * 4 + URI.split(url)[4..-1])).to_s
      @hostname = p_url.host
      if p_url.scheme == 'https'
        @use_ssl = true
        @port = p_url.port ? p_url.port : 443
      else
        @use_ssl = false
        @port = p_url.port ? p_url.port : 80
      end
    end
    @raw_headers = read_headers(io)
    @raw_content = read_content(io, headers_array, method: @method)
    @response = nil
  end

  def initialize_copy(source)
    super
    @response = nil
  end

  # Returns the path of the Request e.g., "/index.html"
  def path
    URI(@url).path
  end

  def headers_array
    Turf::VolatileHeadersArray.new self
  end

  def headers
    Turf::VolatileHeaders.new self
  end

  def cookies
    Turf::VolatileCookies.new self
  end

  def <<(request)
    cookies.merge(request.cookies)
    cookies.merge(request.response.cookies) if request.response
  end

  def content
    decode_content(headers_array, @raw_content)
  end

  # Use to create an HTTP connection based on the Request's
  # attributes. See Request.run
  def connect(proxy: nil)
    super(@hostname, @port, @use_ssl, proxy: proxy)
  end

  ##
  # Run a Request
  #
  # If +sock+ is provided, it will be used as socket. Otherwise
  # a new connection is created.
  #
  # A temporary proxy may be set via the +proxy+ argument.
  #
  # In case of success, a Turf::Response object is returned.
  # This object is also associated with the Request.response attribute.
  def run(sock: nil, chunk_cb: nil, proxy: nil)
    sock ||= connect(proxy: proxy)
    Turf::Session.instance.history << self
    if proxy and not @use_ssl
      p = URI(proxy)
      if p.scheme =~ /\Ahttps?\z/
        url = URI::Generic.new(*(["http", "", @hostname, @port] +
                URI.split(@url)[4..-1])).to_s
        start_line = [@method, url, @http_version].join(" ")
        data = [start_line, @raw_headers, ""].join("\r\n")
        data << @raw_content
        send_all(sock, data)
      else
        raise NotImplementedError
      end
    else
      send_all(sock, to_s)
    end
    @response = read_response(sock)
  end

  ##
  # Returns the string representation of the Request
  def to_s
    if /\ACONNECT\z/i =~ @method
      start_line = [@method, "#{@hostname}:#{@port}", @http_version].join(" ")
    else
      start_line = [@method, @url, @http_version].join(" ")
    end
    data = [start_line, @raw_headers, ""].join("\r\n")
    data << @raw_content
    return data
  end

  def inspect
    '<' + [color_method, @hostname, @url].join(" ") + '>'
  end

  def same_connection?(r)
    @hostname == r.hostname and @port == r.port and @use_ssl == use_ssl
  end

  ##
  # Duplicate the Request and return a Turf::RequestArray
  def *(n)
    Turf::RequestArray.new (1..n).to_a.map { |x| self.clone }
  end

  ##
  # Update the Content-Length header according to the size of
  # Request.raw_content
  def update_content_length
    l = @raw_content.length
    headers_array.delete_all 'Content-Length'
    headers_array << ['Content-Length', l]
  end

  def lazy_inject_at(ip, payloads)
    offset_begin = to_s.index(ip)
    offset_end = offset_begin + ip.length
    return Turf::RequestEnumerator.new do |y|
      loop do
        p = payloads.next.to_s
        nc = to_s[0...offset_begin] + p + to_s[offset_end..-1]
        # FIXME should be more careful
        nc = nc.gsub(/^Content-Length:.*\n/, "")
        nr = Turf::Request.new nc, hostname: @hostname, port: @port, use_ssl: @use_ssl
        nr.update_content_length
        y << nr
      end
    end
  end

  def inject_at(ip, payloads)
    lazy_inject_at(ip, payloads.each).to_ra
  end

  def color_method
    self.class.color_method(@method)
  end

  def self.color_method(method)
    return method.blue if ["GET"].include? method
    return method.green if ["POST", "PUT"].include? method
    return method.yellow if ["CONNECT"].include? method
    return method
  end

  private

  def read_response(sock)
    Turf::Response.new(sock, self, chunk_cb: nil)
  end

end
