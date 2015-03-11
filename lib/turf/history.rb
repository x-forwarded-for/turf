require 'singleton'

class Turf::History < Turf::RequestArray

  include Singleton

  def initialize
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
    History.instance
  end

end
