class Turf::RequestEnumerator < Enumerator

  def run_while(&cond)
    done = Turf::RequestArray.new
    loop do
      r = self.next
      done << r
      r.run
      break if cond and not cond.call(r)
    end
    done
  end

  def run
    run_while { |r| true }
  end

  def run_until(&cond)
    run_while { |r| not cond.call(r) }
  end

  def to_ra
    Turf::RequestArray.new(to_a)
  end

end
