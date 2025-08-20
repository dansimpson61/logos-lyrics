require 'spec_helper'
require_relative '../lyrics_service'

RSpec.describe ChartLyricsService do
  let(:service) { ChartLyricsService.new }

  describe '#search' do
    it 'returns empty array for blank term' do
      expect(service.search('')).to eq([])
      expect(service.search(nil)).to eq([])
    end

    it 'makes HTTP request to ChartLyrics API' do
      # Mock the XML response from ChartLyrics API
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <ArrayOfSearchLyricResult>
          <SearchLyricResult>
            <LyricId>123</LyricId>
            <LyricChecksum>abc123</LyricChecksum>
            <Artist>Queen</Artist>
            <Song>Bohemian Rhapsody</Song>
          </SearchLyricResult>
        </ArrayOfSearchLyricResult>
      XML

      stub_request(:get, "http://api.chartlyrics.com/apiv1.asmx/SearchLyric")
        .with(query: { artist: '', song: 'Queen' })
        .to_return(body: xml_response, status: 200)

      results = service.search('Queen')
      expect(results).to be_an(Array)
      expect(results.size).to eq(1)
      
      track = results.first['track']
      expect(track['artist_name']).to eq('Queen')
      expect(track['track_name']).to eq('Bohemian Rhapsody')
      expect(track['track_id']).to eq('123|abc123')
    end

    it 'handles API errors gracefully' do
      stub_request(:get, "http://api.chartlyrics.com/apiv1.asmx/SearchLyric")
        .with(query: { artist: '', song: 'test' })
        .to_raise(HTTP::TimeoutError)

      expect(service.search('test')).to eq([])
    end
  end

  describe '#fetch_lyrics' do
    it 'returns empty string for invalid track_id' do
      expect(service.fetch_lyrics('')).to eq('')
      expect(service.fetch_lyrics(nil)).to eq('')
      expect(service.fetch_lyrics('invalid')).to eq('')
    end

    it 'fetches lyrics from ChartLyrics API' do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <GetLyricResult>
          <Lyric>Sample lyrics content here</Lyric>
        </GetLyricResult>
      XML

      stub_request(:get, "http://api.chartlyrics.com/apiv1.asmx/GetLyric")
        .with(query: { lyricId: '123', lyricCheckSum: 'abc123' })
        .to_return(body: xml_response, status: 200)

      lyrics = service.fetch_lyrics('123|abc123')
      expect(lyrics).to eq('Sample lyrics content here')
    end

    it 'handles API errors gracefully' do
      stub_request(:get, "http://api.chartlyrics.com/apiv1.asmx/GetLyric")
        .with(query: { lyricId: '123', lyricCheckSum: 'abc123' })
        .to_raise(HTTP::ConnectionError)

      expect(service.fetch_lyrics('123|abc123')).to eq('')
    end
  end

  describe '#can_handle_track_id?' do
    it 'returns true for valid ChartLyrics track_id format' do
      expect(service.can_handle_track_id?('123|abc123')).to be true
      expect(service.can_handle_track_id?('456|def456')).to be true
    end

    it 'returns false for invalid formats' do
      expect(service.can_handle_track_id?('invalid')).to be false
      expect(service.can_handle_track_id?('123')).to be false
      expect(service.can_handle_track_id?('|abc123')).to be false
      expect(service.can_handle_track_id?('123|')).to be false
      expect(service.can_handle_track_id?('')).to be false
      expect(service.can_handle_track_id?(nil)).to be false
    end
  end
end