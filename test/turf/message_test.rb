require_relative '../test_helper'

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

  def test_parse_headers
    hds = "A: 1 \nB: 2\r\nC: 3\r\n"
    assert_equal(@message.parse_headers(StringIO.new(hds)), ([["A","1"],["B","2"],["C","3"]]))
  end

  def test_has_headers_1
    hds = [["A","1"], ["C","3"]]
    assert_equal(@message.has_header(hds, 'A'), true)
  end

  def test_has_headers_2
    hds = [["A","1"], ["C","3"]]
    assert_equal(@message.has_header(hds, 'A', '2'), false)
  end

  def test_has_headers_3
    hds = [["A","1"], ["C","3"]]
    assert_equal(@message.has_header(hds, 'A', '1'), true)
  end

  def test_get_header
    hds = [["A","1"], ["C","3"]]
    assert_equal(@message.get_header(hds, "a"), ["1"])
  end

  def test_read_content_fixed
    hds = [["Content-Length", "2"]]
    assert_equal(@message.read_content(@io, hds), "ab")
  end

  def test_read_content_status_200
    assert_equal(@message.read_content(@io, [], status: "200"), "abc")
  end

  def test_read_content_status_304
    assert_equal(@message.read_content(@io, [], status: "304"), "")
  end

  def test_read_content_post
    assert_equal(@message.read_content(@io, [], method: "POST"), "abc")
  end

end

