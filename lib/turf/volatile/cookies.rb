require 'forwardable'

module Turf

  ## This class behave like a hash for the cookies
  #  but forward any modification to the request @raw_headers
  class VolatileCookies

    extend Forwardable

    def_delegators :parse, :empty?

    def initialize(r)
      @r = r
      if @r.is_a? Turf::Response
        @header_name = 'Set-Cookie'
      else
        @header_name = 'Cookie'
      end
    end

    def [](key)
      c = parse[key]
      c.nil? ? nil : c.value
    end

    def []=(key, value)
      cookies = parse
      cookies[key] = Turf::Cookie.new key, value
      build cookies
    end

    def merge(other_cookies)
      cookies = parse
      cookies.merge!(other_cookies.to_h)
      build cookies
    end

    def delete(key)
      cookies = parse
      cookies.delete(key)
      build cookies
    end

    def to_h
      parse
    end

    private

    def parse
      Hash[ @r.headers_array.get_all(@header_name).collect { |v|
        Turf::Cookie.parse(v, @header_name == 'Set-Cookie').collect { |c|
          [c.name, c]
        }
      }.flatten(1)]
    end

    def build(cookies)
      @r.headers_array.delete_all @header_name
      cookies.each { |name, c|
        @r.headers_array << [@header_name, c.build]
      }
    end

  end

end
