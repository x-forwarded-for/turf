class PrintRequest < Turf::Proxy::RequestPlugin

  def self.run(proxy, proxy_thread)
    proxy.ui.info(proxy_thread.request.to_s)
  end

end
