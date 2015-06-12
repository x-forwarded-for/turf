require 'forwardable'

class Turf::RequestArray
  extend Forwardable
  def_delegators :@array, :[], :<<, :collect, :each, :empty?, :length

  def initialize(array = [])
    @array = array
  end

  def run(slice: nil)
    conn = nil
    prev = nil
    slice ||= @array
    slice.each do |r|
      if not conn or not r.same_connection? prev
        conn = r.connect
      end
      r.run sock: conn
      prev = r
    end
  end

  def parallel(threads: 4)
    tds = []
    @array.group_by.with_index { |o, i| i % threads }.each_value { |slice|
      tds << Thread::new(slice) { |s| run slice: s }
    }
    tds.each { |t| t.join }
    nil
  end

  def select(&block)
    Turf::RequestArray.new(@array.select &block)
  end

  def done
    select { |r| not r.response.nil? }
  end

  def to_a
    @array
  end

  def inspect
    status = Hash.new 0
    each { |r|
      if r.response
        status[r.response.status] += 1
      else
        status["unknown"] += 1
      end
    }
    st = status.to_a.collect{ |k,v| "#{Turf::Response.color_status(k)}:#{v}" }.join(" ")
    hostnames = collect { |r| r.hostname }.uniq.join(", ")
    return "<#{length} | #{st} | #{hostnames}>"
  end

  def to_s
    columns = [ {name: "Method",
                       cb: Proc.new { |x| x.color_method }
                       },
                {name: "Hostname",
                       cb: Proc.new { |x| x.hostname },
                       weight: 0.1,
                       adjust_cb: :character_truncate,
                       adjust_args: "." },
                {name: "Path",
                       cb: Proc.new { |x| x.path },
                       weight: 0.2,
                       adjust_cb: :character_rtruncate,
                       adjust_args: "/" },
                {name: "Length", cb: Proc.new { |x|
                       x.response.nil? ? "-" : Turf.human_readable_size(x.response.length)
                       }},
                {name: "Status", cb: Proc.new {
                       |x| x.response.nil? ? "-" : Turf::Response.color_status(x.response.status)
                    }}
              ]
    Turf::tp self, columns
  end

end
