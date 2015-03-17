require 'uri'
require 'colorize'

class Turf::Request

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
      raise Exception.new("No scheme!") if not p_url.scheme
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
    @raw_content = read_content(io, headers, method: @method)
    @response = nil
  end

  def initialize_copy(source)
    super
    @response = nil
  end

  def headers
      parse_headers(@raw_headers)
  end

  def connect(proxy: nil)
    super(@hostname, @port, @use_ssl, proxy: proxy)
  end

  def run(sock = nil, chunk_cb: nil, proxy: nil)
    sock ||= connect(proxy: proxy)
    Turf::History.instance << self
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

  def read_response(sock)
    Turf::Response.new(sock, self, chunk_cb: nil)
  end

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
    '<' + [color_method(@method), @hostname, @url].join(" ") + '>'
  end

  def *(n)
    RequestArray.new (1..n).to_a.map { |x| self.clone }
  end

  def update_content_length
    l = @raw_content.length
    @raw_headers = build_headers(add_header(remove_header(headers,
                      'Content-Length'), 'Content-Length', l))
  end

  def inject_at(ip, payloads)
    offset_begin = to_s.index(ip)
    offset_end = offset_begin + ip.length
    rs = Turf::RequestArray.new payloads.collect { |p|
      nc = to_s[0...offset_begin] + p + to_s[offset_end..-1]
      nc = nc.gsub(/^Content-Length:.*\n/, "")
      nr = Turf::Request.new nc, hostname: @hostname, port: @port, use_ssl: @use_ssl
      nr.update_content_length
      nr
    }
    return rs
  end

  private

  def color_method(method)
    return method.blue if ["GET"].include? method
    return method.green if ["POST", "PUT"].include? method
    return method.yellow if ["CONNECT"].include? method
    return method
  end

end
