module Turf

  def Turf.human_readable_size(s)
    units = ["", "k", "M"]
    size, unit = units.reduce(s.to_f) do |(fsize, _), utype|
      fsize > 500 ? [fsize / 1000, utype] : (break [fsize, utype])
    end
    "#{size > 9 || size.modulo(1) < 0.1 ? '%d' : '%.1f'}%s" % [size, unit]
  end

  def Turf.screen_width
    if defined?(Pry)
      Pry::Terminal.width!
    elsif $stdout.tty? && $stdout.respond_to?(:winsize)
      $stdout.winsize.last
    else
      80
    end
  end

  class TablePrinter

    def initialize(requests, columns, width: nil)
      @requests = requests
      @width = width || Turf.screen_width
      @columns = expand_columns(columns)
      # Build all the rows with their contents,
      # expanded_columns may be modified
      @rows = build
      # Find which columns overflow and adjust
      adjust_width
    end

    def truncate(s, max_len, *args)
      s[0..max_len-1]
    end

    def character_rtruncate(s, max_len, *args)
      character_truncate(s.reverse, max_len, *args).reverse
    end

    def character_truncate(s, max_len, *args)
      # Truncate the string, using a splitting character
      c = args[0]
      if s.length > max_len
        if s[1..-1].include? c
          init_length = s.length
          pl = init_length + 1
          while s.length > max_len - 2
            break if pl == s.length
            pl = s.length
            s = s.split(c, 2).last
          end
          if s.length != init_length
            s = "\u2026" + c + s
          end
        end
        if s.length > max_len
          s = s[0..max_len] + "\u2026"
        end
      end
      s
    end

    def expand_columns(columns)
      # Each column must have the keys :name, :width, :cb, :weight.
      # :adjust_cb must be defined if :weight != nil
      columns.collect { |c|
        if c.is_a?(Symbol)
          column = Hash.new
          column[:name] = c.to_s.capitalize
          column[:width] = column[:name].length
          column[:cb] = Proc.new { |x| x.send(c) }
          column[:weight] = nil
          column
        else
          if not c.key?(:name) or not c.key?(:cb)
            raise Exception.new ":name and :cb are mandatory"
          end
          c[:width] ||= c[:name].length
          c[:weight] ||= nil
          c[:adjust_cb] ||= :truncate
          c
        end
      }
    end

    def build
      # Populate rows and update columns length if necessary
      rows = @requests.collect.with_index do |r, idx|
        @columns.collect { |column|
          v = column[:cb].call(r, idx).to_s
          n = column[:name]
          if v.uncolorize.length > column[:width]
            column[:width] = v.uncolorize.length
          end
          v
        }
      end
    end

    def render
      thead = @columns.collect { |c| c[:name].ljust(c[:width]) }.join(" ")
      tbody = @rows.collect { |row|
        row.collect.with_index { |cell, i|
          col = @columns[i]
          if cell.uncolorize.length > col[:width]
            cell = send(col[:adjust_cb], cell, col[:width], col[:adjust_args])
          end
          colorized_ljust(cell, col[:width])
        }.join(" ")
      }.join("\n")
      [thead, tbody].join("\n")
    end

    def adjust_width
      adjustables = @columns.select { |c| c[:weight] }
      fixed = @columns - adjustables
      # Share the remaining width between all adjustables columns
      loop do
        done = true
        remaining_width = @width - fixed.inject(0) {|m, c| m + c[:width] + 1}
        total_weight = adjustables.inject(0) {|m, c| m + c[:weight]}
        adjustables.each { |a|
          allocated_width = remaining_width * (a[:weight].to_f/total_weight) - 1
          # If we have over-allocated space for one column,
          # redistribute the excess to the others
          if allocated_width > a[:width]
            adjustables.delete(a)
            fixed << a
            done = false
          end
        }
        break if done
      end
      # For the columns that have not been succesfully adjusted
      # truncate the width according to their preferences
      remaining_width = @width - fixed.inject(0) {|m, c| m + c[:width] + 1}
      total_weight = adjustables.inject(0) {|m, c| m + c[:weight]}
      adjustables.each { |a|
        a[:width] = remaining_width * (a[:weight].to_f/total_weight) - 1
      }
    end

    private

    def colorized_ljust(s, w)
      # Left adjust a string that is colorized
      s + (" " * (w - s.uncolorize.length))
    end

  end

  module_function

  def tp(requests, fields, width: nil)
    tp = TablePrinter.new requests, fields, width: width
    tp.render
  end

end

