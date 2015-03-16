require 'openssl'

module Turf

  class CertificateAuthority

    def initialize
      @key_path = File.join Configuration.instance.cert_dir, "key.pem"
      @cert_path = File.join Configuration.instance.cert_dir, "cert.pem"
    end

    def key
      if File.exist?(@key_path)
        key = OpenSSL::PKey::RSA.new File.read @key_path
      else
        key = generate_ca_key
      end
    end

    def ca_certificate
      if File.exist?(@cert_path)
        return OpenSSL::X509::Certificate.new File.read @cert_path
      else
        return generate_ca_cert
      end
    end

    def certificate(hostname)
      cert_path = File.join(Configuration.instance.site_cert_dir, "#{hostname}.pem")
      if File.exist?(cert_path)
        return OpenSSL::X509::Certificate.new File.read cert_path
      else
        return generate_cert hostname
      end
    end


    private

    def generate_serial
      Random.new.bytes(4).unpack("H*")[0].to_i(16)
    end

    def generate_ca_key
      key = OpenSSL::PKey::RSA.new 2048
      open @key_path, 'w' do |io| io.write key.to_pem end
      return key
    end

    def generate_ca_cert
      ca_name = OpenSSL::X509::Name.parse 'C=AU/O=X-Forwarded-For/CN=turf'
      ca_cert = OpenSSL::X509::Certificate.new
      ca_cert.serial = generate_serial
      ca_cert.version = 2
      ca_cert.not_before = Time.now
      ca_cert.not_after = Time.now + (60 * 60 * 24 * 365 * 5)

      ca_cert.public_key = key.public_key
      ca_cert.subject = ca_name
      ca_cert.issuer = ca_name

      extension_factory = OpenSSL::X509::ExtensionFactory.new
      extension_factory.subject_certificate = ca_cert
      extension_factory.issuer_certificate = ca_cert

      ca_cert.add_extension \
        extension_factory.create_extension('subjectKeyIdentifier', 'hash')
      ca_cert.add_extension \
        extension_factory.create_extension('basicConstraints', 'CA:TRUE', true)

      ca_cert.sign key, OpenSSL::Digest::SHA1.new
      open @cert_path, 'w' do |io| io.write ca_cert.to_pem end
      return ca_cert
    end

    def generate_cert(hostname)
      name = OpenSSL::X509::Name.parse "O=Turf/CN=#{hostname}"
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = generate_serial
      cert.not_before = Time.now
      cert.not_after = Time.now + (60 * 60 * 24 * 365)

      cert.public_key = key.public_key
      cert.subject = name
      cert.issuer = ca_certificate.subject

      extension_factory = OpenSSL::X509::ExtensionFactory.new
      extension_factory.subject_certificate = cert
      extension_factory.issuer_certificate = ca_certificate

      cert.sign key, OpenSSL::Digest::SHA1.new
      open File.join(Configuration.instance.site_cert_dir,
          "#{hostname}.pem"), 'w' do |io|
        io.write cert.to_pem
      end
      return cert
    end

  end

end
