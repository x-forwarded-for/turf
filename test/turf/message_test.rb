require_relative "../test_helper"

class MessageTest < MiniTest::Test

  def setup
    @message = Class.new.extend(Turf::Message)
    @io = StringIO.new "abc"
  end

  def test_read_start_line
    assert_equal(@message.read_start_line(StringIO.new("GET     /   HTTP/1. 1")), ["GET", "/", "HTTP/1. 1"])
  end

  def test_read_headers_newline
    assert_equal(@message.read_headers(StringIO.new("A: 1\nB: 2\n\n")), ("A: 1\nB: 2\n"))
  end

  def test_read_headers_newline_and_carriage_return
    assert_equal(@message.read_headers(StringIO.new("A: 1\nB: 2\n\r\n")), ("A: 1\nB: 2\n"))
  end

end
