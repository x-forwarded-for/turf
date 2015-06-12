require_relative '../test_helper'

class RequestArrayTest < MiniTest::Test

  def setup
    @ws, @ws_port = start_basic_webrick
  end

  def teardown
    @ws.terminate
  end

  def test_inspect
    ra = Turf::get("http://127.0.0.1:#{@ws_port}/") * 2
    assert_includes(ra.inspect.uncolorize, "unknown:2")
    ra.run
    assert_includes(ra.inspect.uncolorize, "200:2")
  end

  def test_to_s
    ra = Turf::get("http://127.0.0.1:#{@ws_port}/") * 2
    refute_includes(ra.to_s, "200")
    ra.run
    assert_includes(ra.to_s, "200")
  end

  def test_parallel
    r = Turf::get("http://127.0.0.1:#{@ws_port}/")
    ra = r * 7
    assert_equal(0, ra.done.length)
    ra.parallel
    assert_equal(7, ra.done.length)
  end

end
