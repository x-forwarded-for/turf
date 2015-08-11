require "singleton"

module Turf

  class Configuration

    attr_reader :path

    DEFAULT_PATH = "~/.turf"

    def initialize(path = nil)
      @path = path || File.expand_path(DEFAULT_PATH)
      Dir.mkdir(@path, 0700) unless Dir.exist?(@path)
      Dir.mkdir(cert_dir, 0700) unless Dir.exist?(cert_dir)
      Dir.mkdir(session_dir, 0700) unless Dir.exist?(session_dir)
    end

    def cert_dir
      File.join(@path, "certs")
    end

    def session_dir
      File.join(@path, "sessions")
    end

  end

  module_function

  def conf
    @conf ||= Configuration.new
  end

  def set_conf_path(path)
    @conf = Configuration.new path
  end

end
