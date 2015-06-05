class Turf::RequestArray < Array

  def run(slice: nil)
    conn = nil
    prev = nil
    slice ||= self
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
    group_by.with_index { |o, i| i % threads }.each_value { |slice|
      tds << Thread::new(slice) { |s| run slice: s }
    }
    tds.each { |t| t.join }
    nil
  end

  def select(&block)
    if block_given?
      Turf::RequestArray.new(super.select &block)
    else
      super
    end
  end

  def done
    select { |r| not r.response.nil? }
  end

  def inspect
    status = Hash.new 0
    each { |r|
      if r.response
        status[r.response.status] += 1
      else
        status["unkown"] += 1
      end
    }
    st = status.to_a.collect{ |k,v| "#{Turf::Response.color_status(k)}:#{v}" }.join(" ")
    hostnames = collect { |r| r.hostname }.uniq.join(", ")
    return "<#{length} | #{st} | #{hostnames}>"
  end

end
