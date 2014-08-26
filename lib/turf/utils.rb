module Turf

  module_function

  def human_readable_size(s)
    units = ["", "k", "M"]
    size, unit = units.reduce(s.to_f) do |(fsize, _), utype|
      fsize > 500 ? [fsize / 1000, utype] : (break [fsize, utype])
    end
    "#{size > 9 || size.modulo(1) < 0.1 ? '%d' : '%.1f'}%s" % [size, unit]
  end

end

