class Turf::Cookie

  attr_accessor :name
  attr_accessor :value
  attr_accessor :attr

  def initialize(name, value, attr = {})
    @name = name
    @value = value
    @attr = attr
  end

  def build
   "#{@name}=#{value}"
  end

  def self.parse(header, set_cookie = false)
    if set_cookie
      pair, av = header.split(";", 2)
      name, value = pair.split("=", 2).map(&:strip)
      avs = parse_attributes av
      Array.new([new(name, value, avs)])
    else
      pairs = header.split(";", 2)
      pairs.collect { |pair|
        name, value = pair.split("=", 2).map(&:strip)
        new name, value
      }
    end
  end

  def self.parse_attributes(av)
    {}
  end

end
