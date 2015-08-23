require "date"
require "singleton"

module Turf

  class Session

    include Singleton

    attr_accessor :name
    attr_accessor :history

    def initialize
      @name = "default"
      @history = History.new
    end

    def save
      s = { history: @history.to_a }
      b = IRB.conf[:MAIN_CONTEXT].workspace.binding
      b.eval("local_variables").each { |v|
        s[v] = b.local_variable_get(v)
      }
      dir = File.join(Turf.conf.session_dir, @name)
      Dir.mkdir(dir, 0700) unless Dir.exist?(dir)
      fname = File.join(dir, DateTime.now.iso8601)
      File.open(fname, "wb", 0600) { |f|
        f.write(Marshal.dump(s))
      }
      puts "Saved under #{fname}"
    end

    def load(name)
      dir = File.join(Turf.conf.session_dir, name)
      fname = Dir.glob(File.join(dir, "*")).last
      if File.exist?(fname)
        puts "Loading #{fname}"
        @name = name
        s = Marshal.load(File.open(fname))
        b = IRB.conf[:MAIN_CONTEXT].workspace.binding
        s.reject { |k,v| k == :history }.each { |k,v|
          b.local_variable_set(k, v)
        }
        @history = History.new s[:history]
      end
      nil
    end

  end

  module_function

  ##
  # Save the session under a particular name
  # If no name is provided, "default" will be used
  def save(name = nil)
    Session.instance.name = name unless name.nil?
    Session.instance.save
  end

  ##
  # Restore a session previously saved
  def restore(name)
    Session.instance.load name
  end

end
