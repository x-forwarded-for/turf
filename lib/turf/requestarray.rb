class Turf::RequestArray < Array

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
    return "<#{length} ~ #{st} | #{hostnames}>"
  end

end
