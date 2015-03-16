require_relative '../test_helper'

class CertificateAuthorityTest < MiniTest::Test

  def test_new
    ca = Turf::CertificateAuthority.new
    ca.key
    ca.ca_certificate
    ca.certificate("example.org")
  end

end
