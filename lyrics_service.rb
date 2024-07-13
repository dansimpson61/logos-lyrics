# lyrics_service.rb

require 'http' 
require 'json'
require 'uri'

# Base lyrics service class
class LyricsService
  def search(term)
    raise NotImplementedError, 'This method should be implemented by subclasses'
  end

  def fetch_lyrics(track_id)
    raise NotImplementedError, 'This method should be implemented by subclasses'
  end
end

# Musixmatch service subclass
class MusixmatchService < LyricsService
#  API_KEY = ENV['MUSIXMATCH_API_KEY']
  API_KEY = 'f5c171c61c448f24f1f333cd7ee51019'
  BASE_URL = 'https://api.musixmatch.com/ws/1.1/'

  def search(term)
    url = "#{BASE_URL}track.search?q_track_artist=#{URI.encode_www_form_component(term)}&page_size=10&page=1&s_track_rating=desc&apikey=#{API_KEY}"
    response = HTTP.get(url)
    JSON.parse(response.body.to_s)['message']['body']['track_list'].select { |track| track['track']['has_lyrics'] }
  end

  def fetch_lyrics(track_id)
    url = "#{BASE_URL}track.lyrics.get?track_id=#{track_id}&apikey=#{API_KEY}"
    response = HTTP.get(url)
    JSON.parse(response.body.to_s)['message']['body']['lyrics']['lyrics_body']
  end
end

# Lyrics.ovh service subclass
class LyricsOvhService < LyricsService
  BASE_URL = 'https://api.lyrics.ovh/v1/'

  def search(term)
    url = "#{BASE_URL}suggest/#{URI.encode_www_form_component(term)}"
    response = HTTP.get(url)
    JSON.parse(response.body.to_s)['data'].select { |track| track['title'] && track['artist']['name'] }
  end

  def fetch_lyrics(track_id)
    url = "#{BASE_URL}#{URI.encode_www_form_component(track_id)}"
    response = HTTP.get(url)
    JSON.parse(response.body.to_s)['lyrics']
  end
end