# service_manager.rb

class ServiceManager
  def initialize(services)
    @services = services.each_with_object({}) do |service, hash|
      service_name = service.class.name.gsub('Service', '').downcase
      hash[service_name] = service
    end
  end

  def search(term)
    all_results = []
    debug_info = {}

    threads = @services.map do |name, service|
      Thread.new do
        begin
          results = service.search(term)
          { name: name, results: results, error: nil }
        rescue => e
          { name: name, results: [], error: e.message }
        end
      end
    end

    threads.each do |thread|
      result = thread.value
      all_results.concat(result[:results])
      if result[:error]
        debug_info[result[:name]] = result[:error]
      end
    end

    {
      results: all_results,
      debug_info: debug_info
    }
  end

  def fetch_lyrics(track_id, service_name)
    service = @services[service_name.downcase]
    if service
      service.fetch_lyrics(track_id)
    else
      raise "Service '#{service_name}' not found."
    end
  end
end
