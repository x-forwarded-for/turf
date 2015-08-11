require "forwardable"

module Turf

  ## This class behave like an array for the headers
  #  but forward any modification to the request/response @raw_headers
  class VolatileHeadersArray

    extend Forwardable

    def_delegators :parse, :each, :select, :collect, :[]

    def initialize(r)
      @r = r
    end

    def <<(nv)
      name, value = nv
      @r.raw_headers = build(parse + [[name, value]])
    end

    def include?(name, value = nil)
      parse.each do |n, v|
        if n.downcase == name.downcase
          return true if not value or v.downcase == value.downcase
          return false
        end
      end
      false
    end

    def get_all(name)
      parse.select { |n, v| n.downcase == name.downcase }.map(&:last)
    end

    def get_first(name)
      get_all(name).first
    end

    def get_last(name)
      get_all(name).last
    end

    def delete_all(name)
      @r.raw_headers = build(parse.select { |n,v| n != name })
    end

    #def delete_first(name)
    #end

    #def delete_last(name)
    #end

    def to_a
      parse
    end

    private

    def parse
      headers = Array.new
      @r.raw_headers.each_line do |l|
        unless l.empty?
          headers << l.split(":", 2).map(&:strip)
        end
      end
      headers
    end

    def build(headers)
      (headers.collect { |n, v| "#{n}: #{v}" } + [""]).join("\r\n")
    end

  end

end
