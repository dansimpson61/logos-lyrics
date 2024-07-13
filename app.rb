#app.rb

require 'sinatra'
require 'puma'
require 'json'
require 'rack/cors'
require_relative 'lyrics_service.rb' # Require the lyrics service file

# Initialize your lyrics service
lyrics_service = MusixmatchService.new
#lyrics_service = LyricsOvhService.new

use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [:get, :post, :put, :delete, :options]
  end
end

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
    results = lyrics_service.search(term)
    { success: true, results: results }.to_json
  rescue => e
    { success: false, error: e.message }.to_json
  end
end

# Route to fetch lyrics
get '/lyrics' do
  content_type :json
  track_id = params['track_id']
  begin
    lyrics = lyrics_service.fetch_lyrics(track_id)
    { success: true, lyrics: lyrics }.to_json
  rescue => e
    { success: false, error: e.message }.to_json
  end
end
