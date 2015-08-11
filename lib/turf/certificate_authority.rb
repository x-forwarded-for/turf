require "openssl"
require "securerandom"

module Turf

  class CertificateAuthority

    def certificate(hostname)
      unless File.exist? certificate_path(hostname)
        generate_certificate(hostname)
      end
      return OpenSSL::X509::Certificate.new(File.read(certificate_path(hostname)))
    end

    def key
      key_path = File.join(Turf.conf.path, "key.pem")
      unless File.exist? key_path
        generate_ca_key(key_path)
      end
      return OpenSSL::PKey::RSA.new(File.read(key_path))
    end

    def ca_certificate
      ca_cert_path = File.join(Turf.conf.path, "cert.pem")
      unless File.exist?(ca_cert_path)
        generate_ca_certificate(ca_cert_path)
      end
      return OpenSSL::X509::Certificate.new(File.read(ca_cert_path))
    end

    private

    def certificate_path(hostname)
      # i think we are assuming cert_dir exists, could instead use FileUtils.mkdir_p
      File.join(Turf.conf.cert_dir, "#{hostname}.pem")
    end

    def generate_serial
      SecureRandom.random_number(0xffffffff)
    end

    def generate_ca_key(key_path)
      key = OpenSSL::PKey::RSA.new 2048
      File.open(key_path, "w") do |f|
        f.write(key.to_pem)
      end
    end

    def generate_ca_certificate(ca_cert_path)
      ca_name = OpenSSL::X509::Name.parse "C=AU/O=X-Forwarded-For/CN=turf"
      ca_certificate = OpenSSL::X509::Certificate.new
      ca_certificate.serial = generate_serial
      ca_certificate.version = 2
      ca_certificate.not_before = Time.now
      ca_certificate.not_after = Time.now + (60 * 60 * 24 * 365 * 5)

      ca_certificate.public_key = key.public_key
      ca_certificate.subject = ca_name
      ca_certificate.issuer = ca_name

      extension_factory = OpenSSL::X509::ExtensionFactory.new
      extension_factory.subject_certificate = ca_certificate
      extension_factory.issuer_certificate = ca_certificate

      ca_certificate.add_extension(
        extension_factory.create_extension("subjectKeyIdentifier", "hash")
      )
      ca_certificate.add_extension(
        extension_factory.create_extension("basicConstraints", "CA:TRUE", true)
      )

      ca_certificate.sign key, OpenSSL::Digest::SHA1.new
      File.open(ca_cert_path, "w") do |f|
        f.write(ca_certificate.to_pem)
      end
    end

    def generate_certificate(hostname)
      name = OpenSSL::X509::Name.parse("O=Turf/CN=#{hostname}")
      certificate = OpenSSL::X509::Certificate.new
      certificate.version = 2
      certificate.serial = generate_serial
      certificate.not_before = Time.now
      certificate.not_after = Time.now + (60 * 60 * 24 * 365)

      certificate.public_key = key.public_key
      certificate.subject = name
      certificate.issuer = ca_certificate.subject

      extension_factory = OpenSSL::X509::ExtensionFactory.new
      extension_factory.subject_certificate = certificate
      extension_factory.issuer_certificate = ca_certificate

      certificate.sign(key, OpenSSL::Digest::SHA1.new)
      File.open(certificate_path(hostname), "w") do |f|
        f.write(certificate.to_pem)
      end
    end

  end
end
