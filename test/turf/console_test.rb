require_relative "../test_helper"

require "tempfile"

class ConsoleTest < MiniTest::Test

  def test_new
    commands = Tempfile.new("turf-test-command")
    commands.write("puts 3+4\n")
    commands.rewind
    console = Turf::Console.new(file: commands.path)
    console.eval_input
  end

end

