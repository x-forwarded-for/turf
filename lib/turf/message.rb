require "openssl"
require "zlib"

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

  def read_content(io, vha, status: nil, method: nil, chunk_cb: nil)
    return "" if %w{204 304}.include? status
    if vha.include?("Transfer-Encoding", "chunked")
      return read_chunked(io)
    elsif vha.include?("Content-Length")
      l = vha.get_first("Content-Length").to_i
      raise Exception("Invalid Content-Length") if l < 0
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

  def unchunk_content(raw_content)
    content_io = StringIO.new raw_content
    buffer = ""
    loop do
      s = content_io.readline.to_i(16)
      return buffer if s == 0
      buffer << read_exactly(content_io, s)
      content_io.readline
    end
  end

  def decode_content(vha, raw_content)
    if vha.include?("Transfer-Encoding", "chunked")
      c = unchunk_content(raw_content)
    else
      c = raw_content
    end
    if vha.include?("Content-Encoding", "gzip")
      i = Zlib::Inflate.new(32 + Zlib::MAX_WBITS)
      c = i.inflate(c)
    elsif vha.include?("Content-Encoding", "deflate")
      i = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      c = i.inflate(c)
    end
    return c
  end

  def wrap_socket(sock)
    tls_sock = OpenSSL::SSL::SSLSocket.new(sock)
    tls_sock.connect
    return tls_sock
  end

  def http_connect(hostname, port, use_ssl, proxy_hostname, proxy_port)
    psock = TCPSocket.new(proxy_hostname, proxy_port)
    if use_ssl
      psock.write("CONNECT #{hostname}:#{port} HTTP/1.1\r\n\r\n")
      begin
        v, s, m = read_start_line(psock)
      rescue EOFError
      end
      _ = read_headers(psock)
      psock = wrap_socket(psock)
    end
    return psock
  end

  def direct_connect(hostname, port, use_ssl)
    sock = TCPSocket.new(hostname, port)
    if use_ssl
      sock = wrap_socket(sock)
    end
    return sock
  end

  def connect(hostname, port, use_ssl, proxy: nil)
    if proxy
      url = URI(proxy)
      if url.scheme =~ /\Ahttps?\z/
        return http_connect(hostname, port, use_ssl, url.hostname, url.port)
      else
        raise NotImplementedError
      end
    else
      return direct_connect(hostname, port, use_ssl)
    end
  end

  def send_all(sock, buffer)
    sent = 0
    loop do
      sent += sock.write(buffer[sent..-1])
      break if sent == buffer.bytesize
    end
  end

end
