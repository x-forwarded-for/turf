require_relative "../test_helper"

class RequestEnumTest < MiniTest::Test

  def setup
    @ws, @ws_port = start_basic_webrick
    @r = Turf::post("http://127.0.0.1:#{@ws_port}/", {"var1" => "abcdefgh"})
  end

  def teardown
    @ws.terminate
  end

  def test_take
    re = @r.lazy_inject_at("defgh", (1..Float::INFINITY).lazy.map(&:to_s))
    ra1 = re.take(50)
    assert_equal(50, ra1.length)
    ra2 = re.take(10)
    assert_equal(10, ra2.length)
  end

  def test_run_while
    re = @r.lazy_inject_at("gh", (1..Float::INFINITY).lazy.map(&:to_s))
    ra = re.run_while { |r| r.response.status == "200" }
    assert_equal(12, ra.length)
  end

  def test_run_until
    re = @r.lazy_inject_at("gh", (1..Float::INFINITY).lazy.map(&:to_s))
    ra = re.run_until { |r| r.response.status != "200" }
    assert_equal(12, ra.length)
  end
end
