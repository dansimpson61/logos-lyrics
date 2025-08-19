require 'spec_helper'
require_relative '../lyrics_service'

RSpec.describe BigLyricsService do
  let(:service) { BigLyricsService.new }

  describe '#search' do
    it 'finds songs via DuckDuckGo site search' do
      # Stub DuckDuckGo HTML results page containing a redirect link to a BigLyrics song page
      stub_request(:get, %r{https://duckduckgo\.com/html/\?q=.*})
        .to_return(body: File.read('spec/fixtures/biglyrics_search_ddg.html'))

      results = service.search('Queen Bohemian Rhapsody')
      expect(results).not_to be_empty
      track = results.first['track']
      expect(track['artist_name']).to eq('Queen')
      expect(track['track_name']).to eq('Bohemian Rhapsody Lyrics')
      expect(track['track_id']).to eq('https://www.biglyrics.net/queen_lyrics/bohemian_rhapsody.html')
    end
  end

  describe '#fetch_lyrics' do
    it 'parses lyrics from the BigLyrics song page' do
      url = 'https://www.biglyrics.net/queen_lyrics/bohemian_rhapsody.html'
      stub_request(:get, url)
        .to_return(body: File.read('spec/fixtures/biglyrics_lyrics.html'))

      lyrics = service.fetch_lyrics(url)
      expect(lyrics).to eq("Is this the real life?\nIs this just fantasy?")
    end
  end

  describe '#can_handle_track_id?' do
    it 'returns true for biglyrics.net URLs' do
      expect(service.can_handle_track_id?('https://biglyrics.net/frank_sinatra_lyrics/all_the_way.html')).to be true
      expect(service.can_handle_track_id?('https://www.biglyrics.net/queen_lyrics/bohemian_rhapsody.html')).to be true
    end

    it 'returns false for other domains' do
      expect(service.can_handle_track_id?('https://example.com/foo')).to be false
    end
  end
end
