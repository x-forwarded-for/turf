require_relative "../test_helper"

class UtilsTest < MiniTest::Test

  def test_tableprinter
    ra = Turf.get("http://this.is.a.very.long.domain.name.org/and/a/very/long/path/that/will/overflow/the/terminal/width/for/sure.html") * 4
    fields = [{ name: "Hostname",
                cb: Proc.new { |x| x.hostname},
                weight: 0.2,
                adjust_cb: :character_truncate,
                adjust_args: "."
             },
              :port,
             { name: "Path",
                cb: Proc.new { |x| x.path },
                weight: 0.2,
                adjust_cb: :character_rtruncate,
                adjust_args: "/"
             },
             { name: "Status",
                cb: Proc.new { |x| x.response.nil? ? "-" : x.response.status}
             }
             ]
    tp = Turf::TablePrinter.new(ra, fields, width: 80)
    tos = tp.render
    assert_includes(tos, "….is.a.very.long.domain.name.org")
    assert_includes(tos, "/and/a/very/long/path/that/will/…")
  end

end
