require_relative "../test_helper"

class VolatileCookiesTest < MiniTest::Test

  def test_new
    r = Turf.get("http://example.org/")
    assert_empty(r.cookies)
    assert_nil(r.cookies["sessionid"])
    r.cookies["sessionid"] = "test"
    assert_equal("sessionid=test", r.headers["Cookie"])
    assert_equal("test", r.cookies["sessionid"])
    r.cookies.delete("sessionid")
    assert_nil(r.cookies["sessionid"])
  end

end
