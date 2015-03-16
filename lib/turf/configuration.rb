require 'singleton'

module Turf

  class Configuration

    include Singleton

    attr_reader :path

    def initialize
      @path = File.expand_path('~/.turf') 
      Dir.mkdir(@path, 0700) unless Dir.exist?(@path)
      Dir.mkdir(cert_dir, 0700) unless Dir.exist?(cert_dir)
      Dir.mkdir(site_cert_dir, 0700) unless Dir.exist?(site_cert_dir)
    end

    def cert_dir
      File.join(@path, "certs")
    end
  
    def site_cert_dir
      File.join(@path, "certs", "sites")
    end

  end

  module_function

  def conf
    Configuration.instance
  end
 
end
