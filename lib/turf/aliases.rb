require 'securerandom'

module Turf

  DEFAULT_HEADERS = %Q{Host: %s\r
User-Agent: Mozilla/5.0 (Windows; U; MSIE 9.0; Windows NT 0.9; en-US)\r
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r
Accept-Encoding: gzip, deflate\r
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7}

  GET_TEMPLATE = %Q{GET %s HTTP/1.1\r
#{DEFAULT_HEADERS}\r
\r
}

  POST_TEMPLATE = %Q{POST %s HTTP/1.1\r
#{DEFAULT_HEADERS}\r
Content-Type: application/x-www-form-urlencoded\r
\r
%s}

  MULTIPART_TEMPLATE = %Q{POST %s HTTP/1.1\r
#{DEFAULT_HEADERS}\r
Content-Type: multipart/form-data; boundary=%s\r
\r
%s}

  MULTIPART_VAR = %Q{--%s\r
Content-Disposition: form-data; name="%s"\r
\r
%s}

  MULTIPART_FILE = %Q{--%s\r
Content-Disposition: form-data; name="%s"; filename="%s"\r
Content-Type: application/octet-stream\r
\r
%s}

  module_function

  def get(url)
    host = URI(url).hostname
    Request.new(GET_TEMPLATE % [url, host])
  end

  def post(url, args)
    host = URI(url).hostname
    encoded_args = URI::encode_www_form(args)
    Request.new(POST_TEMPLATE % [url, host, encoded_args])
  end

  def multipart(url, args={})
    host = URI(url).hostname
    boundary = "--#{SecureRandom.hex}"
    content = args.collect { |k,v|
      if v.is_a? File
        MULTIPART_FILE % [boundary, k, File.basename(v.path), v.read]
      else
        MULTIPART_VAR % [boundary, k, v]
      end
    }.push("#{boundary}--").join("\r\n")
    Request.new(MULTIPART_TEMPLATE % [url, host, boundary, content])
  end

end