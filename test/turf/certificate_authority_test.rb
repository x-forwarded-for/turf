require_relative '../test_helper'

class CertificateAuthorityTest < MiniTest::Test

  def test_new
    ca = Turf::CertificateAuthority.new
    puts ca.key
    puts ca.ca_certificate
    puts ca.certificate("example.org")
  end

end
