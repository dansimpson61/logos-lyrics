require 'spec_helper'
require_relative '../lyrics_service'

RSpec.describe SongLyricsService do
  let(:service) { SongLyricsService.new }

  describe '#search' do
    it 'returns a list of songs' do
  stub_request(:get, "https://www.songlyrics.com/index.php?section=search&searchW=test").
        to_return(body: File.read('spec/fixtures/songlyrics_search.html'))

      results = service.search('test')
      expect(results.size).to eq(2)
      expect(results[0]['track']['track_name']).to eq('Bohemian Rhapsody Lyrics')
      expect(results[0]['track']['artist_name']).to eq('Queen')
      expect(results[0]['track']['track_id']).to eq('https://www.songlyrics.com/queen/bohemian-rhapsody-lyrics/')
    end
  end

  describe '#fetch_lyrics' do
    it 'returns the lyrics for a song' do
      stub_request(:get, "https://www.songlyrics.com/queen/bohemian-rhapsody-lyrics/").
        to_return(body: File.read('spec/fixtures/songlyrics_lyrics.html'))

      lyrics = service.fetch_lyrics('https://www.songlyrics.com/queen/bohemian-rhapsody-lyrics/')
      expect(lyrics).to eq("Is this the real life?\nIs this just fantasy?")
    end
  end
end
