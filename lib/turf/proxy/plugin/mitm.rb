class Turf::Proxy::RequestPlugin::Mitm < Turf::Proxy::RequestPlugin

  def self.run(proxy, proxy_thread)
    proxy_thread.client.write "HTTP/1.1 200 Connection established\r\n\r\n"
    context = OpenSSL::SSL::SSLContext.new
    context.cert = proxy.ca.certificate(proxy_thread.request.hostname)
    context.key = proxy.ca.key
    proxy_thread.client = OpenSSL::SSL::SSLSocket.new(proxy_thread.client, context)
    proxy_thread.client.accept
    proxy_thread.request = Turf::Request.new(
      proxy_thread.client,
      hostname: proxy_thread.request.hostname,
      port: proxy_thread.request.port,
      use_ssl: true
    )
    proxy_thread.request_prologue
  end

end
