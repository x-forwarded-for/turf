require "irb"
require "irb/ruby-lex"
require "irb/input-method"
require "irb/locale"
require "irb/completion"

IRB.conf[:LC_MESSAGES] = IRB::Locale.new

# IRB hack to be able to use completion with readline
class DummyContext
  attr_accessor :workspace
end
class DummyWorkspace
  attr_accessor :binding
end
IRB.conf[:MAIN_CONTEXT] = DummyContext.new
IRB.conf[:MAIN_CONTEXT].workspace = DummyWorkspace.new

##
# Console
#
# This class is base on irb/ruby-lex for parsing of the command
# We try to avoid most of the other IRB classes to not get into
# the IRB.conf[] ghetto...
#
class Turf::Console

  BANNER = "Turf - by X-Forwarded-For"

  def initialize(file: nil)
    @scanner = RubyLex.new
    @scanner.exception_on_syntax_error = false
    @last_result = nil
    @binding = TOPLEVEL_BINDING
    if file.nil?
      if defined?(IRB::ReadlineInputMethod) and STDIN.tty?
        IRB.conf[:MAIN_CONTEXT].workspace.binding = @binding
        @io = IRB::ReadlineInputMethod.new
      else
        @io = IRB::StdioInputMethod.new
      end
    else
      @io = IRB::FileInputMethod.new file
    end
    puts BANNER
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
        puts "^C\n"
        raise RubyLex::TerminateLineInput
      end
      l
    end

    @scanner.each_top_level_statement do |line, line_no|
      begin
        @last_result = eval(line, @binding, __FILE__, line_no)
        print "=> ", @last_result.inspect, "\n"
        @binding.local_variable_set "_", @last_result
      rescue Exception => exc
        print exc.class, ": ", exc, "\n"
        # puts exc.backtrace
      end
    end
  end

end
