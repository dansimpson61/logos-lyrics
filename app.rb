#app.rb

require 'dotenv'
Dotenv.load('logos.env')
require 'sinatra'
require 'puma'
require 'json'
require 'rack/cors'
require_relative 'lyrics_service.rb'
require_relative 'service_manager.rb'

# Initialize the services
musixmatch_service = MusixmatchService.new
lyrics_ovh_service = LyricsOvhService.new
azlyrics_service = AZLyricsService.new

# Initialize the service manager with all available services
# Note: Lyrics.ovh is defunct, but we'll keep it for now as an example of a multi-provider setup.
service_manager = ServiceManager.new([
  musixmatch_service,
  lyrics_ovh_service,
  azlyrics_service
])

# use Rack::Cors do
#   allow do
#     origins '*'
#     resource '*', headers: :any, methods: [:get, :post, :put, :delete, :options]
#   end
# end

# Serve static files from the public directory
set :public_folder, 'public'

# Route to serve the index.html file
get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

# Route to search songs or artists
get '/search' do
  content_type :json
  term = params['term']
  begin
    search_data = service_manager.search(term)
    {
      success: true,
      results: search_data[:results],
      debug_info: search_data[:debug_info]
    }.to_json
  rescue => e
    status 500
    { success: false, error: e.message }.to_json
  end
end

# Route to fetch lyrics
get '/lyrics' do
  content_type :json
  track_id = params['track_id']
  service_name = params['service_name']

  unless track_id && service_name
    status 400
    return { success: false, error: 'track_id and service_name are required' }.to_json
  end

  begin
    lyrics = service_manager.fetch_lyrics(track_id, service_name)
    { success: true, lyrics: lyrics }.to_json
  rescue => e
    status 500
    { success: false, error: e.message }.to_json
  end
end
