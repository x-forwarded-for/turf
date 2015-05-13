class Turf::History < Turf::RequestArray

  def initialize(*args)
    super *args
    @lock = Mutex.new
  end

  def << (op)
    @lock.synchronize {
      super op
    }
  end

end

module Turf

  module_function

  def history
    Turf::Session.instance.history
  end

end
