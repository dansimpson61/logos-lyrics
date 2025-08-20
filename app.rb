#app.rb

require 'sinatra'
require 'puma'
require 'json'
require 'rack/cors'
require_relative 'lyrics_service.rb' # Require the lyrics service file

# Initialize your lyrics service
# Use multiple adapters at runtime for resilience; tests still target SongLyrics via manager defaults
set :lyrics_service, LyricsServiceManager.new(services: [
  SongLyricsService.new,
  LyricsFreakService.new,
  BigLyricsService.new,
  ChartLyricsService.new
])

# use Rack::Cors do
#   allow do
#     origins '*'
#     resource '*', headers: :any, methods: [:get, :post, :put, :delete, :options]
#   end
# end

# Serve static files from the public directory
set :public_folder, 'public'

# Root route renders the Slim index view
get '/' do
  slim :index
end

# Route to search songs or artists
get '/search' do
  content_type :json
  term = params['term']
  type = params['type']&.to_sym || :song
  begin
    results = settings.lyrics_service.search(term, type: type)
    { success: true, results: results }.to_json
  rescue => e
    status 200
    { success: false, error: e.class.name }.to_json
  end
end

# Route to fetch lyrics
get '/lyrics' do
  content_type :json
  track_id = params['track_id']
  begin
    lyrics = settings.lyrics_service.fetch_lyrics(track_id)
    { success: true, lyrics: lyrics }.to_json
  rescue => e
    status 400
    { success: false, error: e.message }.to_json
  end
end