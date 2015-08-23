require "forwardable"

module Turf

  ## This class behave like a hash for the headers
  #  but forward any modification to the request/response @raw_headers
  class VolatileHeaders

    extend Forwardable

    def_delegators :parse, :each, :[]

    def initialize(r)
      @r = r
    end

    def []=(key, value)
      @r.raw_headers = build(parse.merge({ key => value }))
    end

    def delete(key)
      @r.raw_headers = build(parse.select { |n,v| n != key })
    end

    def to_h
      parse
    end

    private

    def parse
      Hash[ @r.headers_array.to_a ]
    end

    def build(headers)
      (headers.each.collect { |n, v| "#{n}: #{v}" } + [""]).join("\r\n")
    end

  end

end
