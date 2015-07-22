require_relative '../test_helper'

class CookieTest < MiniTest::Test

  def test_parse
    c = Turf::Cookie.parse("JSESSIONID= 123;", set_cookie = true).first
    assert_equal(c.name, "JSESSIONID")
    assert_equal(c.value, "123")
    assert_empty(c.attr)
  end

end

