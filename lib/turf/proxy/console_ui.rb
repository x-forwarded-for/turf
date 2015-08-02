module Turf
  class Proxy::ConsoleUI

    def initialize
      @lock = Monitor.new
    end

    def info(s, from: nil)
      @lock.synchronize {
        puts with_from(s, from: from)
      }
    end

    def ask(question)
      @lock.synchronize {
        Readline.readline(with_from(question), false).squeeze(" ").strip
      }
    end

    def error(s, from: nil)
      @lock.synchronize {
        puts with_from(s.red, from: from)
      }
    end

    private

    def with_from(s, from: nil)
      from ||= Thread.current["id"]
      "[#{from}] #{s}"
    end

  end
end

