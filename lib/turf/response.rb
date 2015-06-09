
class Turf::Response

  include Turf::Message

  attr_accessor :http_version
  attr_accessor :status
  attr_accessor :reason

  attr_accessor :raw_headers
  attr_accessor :raw_content

  attr_accessor :request

  def initialize(io, request, chunk_cb: nil)
    start_line = read_start_line(io)
    @http_version, @status, @reason = start_line
    @reason ||= ""
    @raw_headers = read_headers(io)
    @request = request

    if @request.method == "HEAD"
      @raw_content = ""
    else
      @raw_content = read_content(io, headers, status: @status, chunk_cb: chunk_cb)
    end
  end

  def headers
    parse_headers(@raw_headers)
  end

  def content
    decode_content(headers, @raw_content)
  end

  def to_s
    start_line = [@http_version, @status, @reason].join(" ")
    data = [start_line, @raw_headers, ""].join("\r\n")
    data << @raw_content
    return data
  end

  def length
    @raw_content.length
  end

  def inspect
    fields = [self.class.color_status(@status),
              Turf.human_readable_size(length)]
    if has_header(headers, 'Content-Type')
      fields << get_header(headers, 'Content-Type')
    end
    return '<' + fields.join(" ") + '>'
  end

  def self.color_status(status)
    return status.green if /\A2/ =~ status
    return status.yellow if /\A3/ =~ status
    return status.red if /\A[45]/ =~ status
    return status
  end

end
