require 'irb'
require 'irb/ruby-lex'
require 'irb/input-method'
require 'irb/locale'

IRB.conf[:LC_MESSAGES] = IRB::Locale.new

##
# Console
#
# This class is base on irb/ruby-lex for parsing of the command
# We try to avoid most of the other IRB classes to not get into
# the IRB.conf[] ghetto...
#
class Turf::Console

  # Hack to get _ alias
  @@last_result = nil

  def initialize
    @scanner = RubyLex.new
    @scanner.exception_on_syntax_error = false
    @binding = TOPLEVEL_BINDING
    @io = IRB::StdioInputMethod.new
  end

  def self.last_result
    @@last_result
  end

  def eval_input
    @scanner.set_prompt do |ltype, indent, continue, line_no|
      if ltype
        @io.prompt = nil
      elsif continue
        @io.prompt = ">>* "
      end
      @io.prompt = ">>> "
    end

    @scanner.set_input(@io) do
      begin
        l = @io.gets
        if l.nil?
          puts "\n"
        end
      rescue Interrupt => exc
        puts exc
        puts "\n"
        raise RubyLex::TerminateLineInput
      end
      l
    end

    @scanner.each_top_level_statement do |line, line_no|
      begin
        @@last_result = eval(line, @binding, __FILE__, line_no)
        print "=> ", @@last_result.inspect, "\n"
        eval("_ = Turf::Console.last_result", @binding)
      rescue Exception => exc
        print exc.class, ": ", exc, "\n"
        #puts exc.backtrace
      end
    end
  end

end
