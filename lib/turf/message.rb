require 'openssl'

module Turf::Message

  def read_start_line(io)
    io.readline.chomp.split(" ", 3)
  end

  def read_headers(io)
    headers = ""
    loop do
      l = io.readline
      break if l =~ /\A\r?\n\z/
      headers << l
    end
    return headers
  end

  def parse_headers(raw_headers)
    headers = Array.new
    raw_headers.each_line do |l|
      unless l.empty?
        headers << l.split(":", 2).map(&:strip)
      end
    end
    return headers
  end

  def get_header(headers, name)
    headers.select { |n, v| n.downcase == name.downcase }.map(&:last)
  end

  def has_header(headers, name, value = nil)
    headers.each do |n, v|
      if n.downcase == name.downcase
        return true if not value or v.downcase == value.downcase
        return false
      end
    end
    return false
  end

  def read_content(io, headers, status: nil, method: nil, chunk_cb: nil)
    return "" if %w{204 304}.include? status
    if has_header(headers, 'Transfer-Encoding', 'chunked')
      return read_chunked(io)
    elsif has_header(headers, 'Content-Length')
      l = get_header(headers, 'Content-Length').first.to_i
      raise Exception('Invalid Content-Length') if l < 0
      return read_exactly(io, l)
    elsif status or %w{POST PUT}.include? method
      return io.read()
    end
    return ""
  end

  def read_chunked(io)
    b = String.new
    loop do
      diff = String.new
      l = io.readline
      diff << l
      s = l.to_i(16)
      if s == 0
        diff << io.readline
        b << diff
        return b
      end
      diff << read_exactly(io, s)
      diff << io.readline
      b << diff
    end
  end

  def read_exactly(io, length)
    b = String.new
    loop do
      l = b.length
      if l < length
        b << io.read(length - l)
      else
        break
      end
    end
    return b
  end

  def wrap_socket(sock)
    return OpenSSL::SSL::SSLSocket.new sock
  end

  def direct_connect(hostname, port, use_ssl)
    sock = TCPSocket.new(hostname, port)
    if use_ssl
      sock = wrap_socket(sock)
    end
    return sock
  end

  def connect(hostname, port, use_ssl)
    direct_connect(hostname, port, use_ssl)
  end

  def send_all(sock, buffer)
    sent = 0
    loop do
      sent += sock.send(buffer[sent..-1], 0)
      break if sent == buffer.length
    end
  end

end
