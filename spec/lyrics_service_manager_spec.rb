require 'spec_helper'
require_relative '../lyrics_service'

RSpec.describe LyricsServiceManager do
  let(:manager) { described_class.new }

  describe '#search' do
    it 'delegates to services and returns grouped, normalized results' do
      stub_request(:get, "https://www.songlyrics.com/index.php?section=search&searchW=queen").
        to_return(body: File.read('spec/fixtures/songlyrics_search.html'))

      # Mock the other services to return empty arrays to isolate the test
      allow_any_instance_of(LyricsFreakService).to receive(:search).and_return([])
      allow_any_instance_of(BigLyricsService).to receive(:search).and_return([])

      results = manager.search('queen')
      expect(results).to be_an(Array)
      expect(results.size).to eq(1) # Only one artist group: Queen

      queen_group = results.first
      expect(queen_group['artist_name']).to eq('Queen')

      tracks = queen_group['tracks']
      expect(tracks).to be_an(Array)
      expect(tracks.size).to eq(2)

      first_track = tracks.first
      expect(first_track['track_name']).to match(/Bohemian Rhapsody/i)
      expect(first_track['track_id']).to match(%r{https?://www\.songlyrics\.com/})
      expect(first_track['source']).to eq('SongLyrics')
    end

    it 'returns empty array for blank term' do
      expect(manager.search('')).to eq([])
      expect(manager.search(nil)).to eq([])
    end
  end

  describe '#fetch_lyrics' do
    it 'dispatches to SongLyricsService based on track_id host' do
      track_url = 'https://www.songlyrics.com/queen/bohemian-rhapsody-lyrics/'
      stub_request(:get, track_url).
        to_return(body: File.read('spec/fixtures/songlyrics_lyrics.html'))

      lyrics = manager.fetch_lyrics(track_url)
      expect(lyrics).to eq("Is this the real life?\nIs this just fantasy?")
    end

    it 'raises error when no adapter can handle the track_id' do
      expect {
        manager.fetch_lyrics('https://example.com/not-supported')
      }.to raise_error(ArgumentError, /No adapter/)
    end

    it 'raises error for missing track_id' do
      expect { manager.fetch_lyrics(nil) }.to raise_error(ArgumentError)
      expect { manager.fetch_lyrics('  ') }.to raise_error(ArgumentError)
    end
  end
end
