module Turf

  GET_TEMPLATE = %q{GET %s HTTP/1.1
Host: %s
User-Agent: Mozilla/5.0 (Windows; U; MSIE 9.0; Windows NT 0.9; en-US)
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Encoding: gzip, deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7

}

  POST_TEMPLATE = %q{POST %s HTTP/1.1
Host: %s
User-Agent: Mozilla/5.0 (Windows; U; MSIE 9.0; Windows NT 0.9; en-US)
Accept-Encoding: gzip, deflate
Content-Type: application/x-www-form-urlencoded

%s
}

  module_function

  def get(url)
    host = URI(url).hostname
    Request.new(GET_TEMPLATE % [url, host])
  end

  def post(url, *args)
    host = URI(url).hostname
    encoded_args = URI::encode_www_form(*args)
    Request.new(POST_TEMPLATE % [url, host, encoded_args])
  end

end
