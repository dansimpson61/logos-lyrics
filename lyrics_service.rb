# lyrics_service.rb

require 'http' 
require 'json'
require 'uri'
require 'nokogiri'
require 'cgi'

# Base lyrics service class
class LyricsService
  def search(term, type: :song)
    raise NotImplementedError, 'This method should be implemented by subclasses'
  end

  def fetch_lyrics(track_id)
    raise NotImplementedError, 'This method should be implemented by subclasses'
  end

  # Identify if this adapter can handle the given track_id
  def can_handle_track_id?(_track_id)
    false
  end
end

# Lyrics Service Manager
class LyricsServiceManager
  def initialize(services: nil)
    # MVP: enable the single, fully working adapter by default
    @services = services || [
      SongLyricsService.new
    ]
  end

  def search(term, type: :song)
    return [] if term.nil? || term.strip.empty?

    results = @services.flat_map { |s| Array(s.search(term, type: type)) }

    # Keep only items whose track_id can be handled by at least one adapter
    results.select! do |item|
      track_id = (item['track'] || {})['track_id']
      @services.any? { |s| s.can_handle_track_id?(track_id) }
    end

    # Normalize-based dedup across adapters
    seen = {}
    results.each_with_object([]) do |item, acc|
      track = item['track'] || {}
      artist = String(track['artist_name']).strip.downcase
      title = String(track['track_name']).strip.downcase.gsub(/\s+lyrics\b/i, '')
      key = [artist, title]
      next if artist.empty? || title.empty? || seen[key]
      seen[key] = true
      acc << item
    end
  end

  def fetch_lyrics(track_id)
    raise ArgumentError, 'track_id required' if track_id.nil? || track_id.to_s.strip.empty?

    service = @services.find { |s| s.can_handle_track_id?(track_id) }
    raise ArgumentError, 'No adapter can handle provided track_id' unless service

    service.fetch_lyrics(track_id)
  end
end


# SongLyrics.com service subclass
class SongLyricsService < LyricsService
  BASE_URL = 'https://www.songlyrics.com'
  HEADERS = {
    'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language' => 'en-US,en;q=0.9',
  'Referer' => 'https://www.songlyrics.com/'
  }

  def search(term, type: :song)
    search_url = "#{BASE_URL}/index.php?section=search&searchW=#{URI.encode_www_form_component(term)}"
    begin
      response = HTTP.timeout(connect: 50, read: 6).headers(HEADERS).get(search_url)
    rescue HTTP::TimeoutError, HTTP::ConnectionError
      return []
    end
    return [] unless response.status.success?

    doc = Nokogiri::HTML(response.body.to_s)

    # Primary parser (existing structure)
    results = doc.css('div.serpresult').map do |item|
      title_element = item.css('h3 a').first
      artist_element = item.css('p a').first
      next unless title_element && artist_element
      href = title_element['href'].to_s
      track_url = if href.start_with?('http://', 'https://')
        href
      elsif href.start_with?('/')
        "#{BASE_URL}#{href}"
      else
        "#{BASE_URL}/#{href}"
      end
      {
        'track' => {
          'track_name' => title_element.text.strip,
          'artist_name' => artist_element.text.strip,
          'track_id' => track_url
        }
      }
    end.compact
    return results unless results.empty?

    # Fallback parser: look for links that match the lyrics URL pattern
    anchors = doc.css('a[href]')
    candidates = anchors.map { |a| a['href'] }.compact.uniq.select { |href|
      href =~ %r{(^https?://www\.songlyrics\.com/[^/]+/[^/]+-lyrics/)|(^/[^/]+/[^/]+-lyrics/)}i
    }

    page_candidates = candidates.map do |href|
      full = href.start_with?('http') ? href : "https://www.songlyrics.com#{href}"
      begin
        uri = URI.parse(full)
        parts = uri.path.split('/').reject(&:empty?)
        artist_slug = parts[0] || ''
        song_slug = (parts[1] || '').sub(/-lyrics\/?\z/i, '')
        artist_name = artist_slug.split('-').map(&:capitalize).join(' ')
        track_name = song_slug.split('-').map(&:capitalize).join(' ')
      rescue
        next
      end
      next if artist_name.empty? || track_name.empty?
      {
        'track' => {
          'track_name' => "#{track_name} Lyrics",
          'artist_name' => artist_name,
          'track_id' => full
        }
      }
    end.compact

    return page_candidates unless page_candidates.empty?

    # Second fallback: use DuckDuckGo to find songlyrics.com results
    ddg_q = URI.encode_www_form_component("site:www.songlyrics.com #{term} lyrics")
    ddg_url = "https://duckduckgo.com/html/?q=#{ddg_q}"
    begin
      ddg_res = HTTP.follow(max_hops: 5).timeout(connect: 5, read: 6).headers(HEADERS).get(ddg_url)
    rescue HTTP::TimeoutError, HTTP::ConnectionError
      return []
    end
    return [] unless ddg_res.status.success?

    ddg_doc = Nokogiri::HTML(ddg_res.body.to_s)
    raw_links = ddg_doc.css('a[href]').map { |a| a['href'] }.compact.uniq
    ddg_candidates = raw_links.flat_map do |href|
      if href.start_with?('https://www.songlyrics.com', 'http://www.songlyrics.com')
        [href]
      elsif href.start_with?('/l/?') || href.include?('uddg=')
        begin
          # DuckDuckGo redirect: /l/?kh=1&uddg=<urlencoded>
          uri = URI.parse(href.start_with?('http') ? href : "https://duckduckgo.com#{href}")
          params = CGI.parse(uri.query.to_s)
          encoded = params['uddg']&.first
          decoded = encoded ? CGI.unescape(encoded) : nil
          decoded && decoded.start_with?('http') ? [decoded] : []
        rescue
          []
        end
      else
        []
      end
    end.select { |u|
      u =~ %r{^https?://www\.songlyrics\.com/[^/]+/[^/]+-lyrics/?$}i
    }.uniq

    mapped = ddg_candidates.map do |full|
      begin
        uri = URI.parse(full)
        parts = uri.path.split('/').reject(&:empty?)
        artist_slug = parts[0] || ''
        song_slug = (parts[1] || '').sub(/-lyrics\/?\z/i, '')
        artist_name = artist_slug.split('-').map(&:capitalize).join(' ')
        track_name = song_slug.split('-').map(&:capitalize).join(' ')
      rescue
        next
      end
      next if artist_name.empty? || track_name.empty?
      {
        'track' => {
          'track_name' => "#{track_name} Lyrics",
          'artist_name' => artist_name,
          'track_id' => full
        }
      }
    end.compact

    return mapped unless mapped.empty?

    # Third fallback: Bing
    bing_q = URI.encode_www_form_component("site:www.songlyrics.com #{term} lyrics")
    bing_url = "https://www.bing.com/search?q=#{bing_q}&setlang=en-US"
    begin
      bing_res = HTTP.follow(max_hops: 5).timeout(connect: 5, read: 6).headers(HEADERS).get(bing_url)
    rescue HTTP::TimeoutError, HTTP::ConnectionError
      return []
    end
    return [] unless bing_res.status.success?

    bing_doc = Nokogiri::HTML(bing_res.body.to_s)
    bing_links = bing_doc.css('li.b_algo h2 a[href], a[href]').map { |a| a['href'] }.compact.uniq
    bing_candidates = bing_links.select { |u|
      u =~ %r{^https?://www\.songlyrics\.com/[^/]+/[^/]+-lyrics/?$}i
    }

    bing_candidates.map do |full|
      begin
        uri = URI.parse(full)
        parts = uri.path.split('/').reject(&:empty?)
        artist_slug = parts[0] || ''
        song_slug = (parts[1] || '').sub(/-lyrics\/?\z/i, '')
        artist_name = artist_slug.split('-').map(&:capitalize).join(' ')
        track_name = song_slug.split('-').map(&:capitalize).join(' ')
      rescue
        next
      end
      next if artist_name.empty? || track_name.empty?
      {
        'track' => {
          'track_name' => "#{track_name} Lyrics",
          'artist_name' => artist_name,
          'track_id' => full
        }
      }
    end.compact
  end

  def fetch_lyrics(track_id)
    response = HTTP.follow(max_hops: 5).timeout(connect: 5, read: 10).headers(HEADERS).get(track_id)
    return '' unless response.status.success?

    doc = Nokogiri::HTML(response.body.to_s)
    lyrics_div = doc.css('#songLyricsDiv').first
    lyrics_div ? lyrics_div.inner_html.gsub('<br>', "\n").gsub(/(\n\s*)+/, "\n").strip : ''
  end

  def can_handle_track_id?(track_id)
    begin
      uri = URI.parse(track_id.to_s)
    rescue URI::InvalidURIError
      return false
    end
    host = uri.host.to_s.downcase
    host.end_with?('songlyrics.com')
  end
end


# LyricsFreak.com service subclass
class LyricsFreakService < LyricsService
  BASE_URL = 'https://www.lyricsfreak.com'
  HEADERS = {
    'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.9',
    'Referer' => 'https://www.lyricsfreak.com/'
  }

  def search(term, type: :song)
    return [] if term.nil? || term.strip.empty?
    # LyricsFreak search page; filter anchors matching song URL pattern
    search_url = "#{BASE_URL}/search.php?a=search&type=song&q=#{URI.encode_www_form_component(term)}"
    begin
      res = HTTP.timeout(connect: 5, read: 6).headers(HEADERS).get(search_url)
    rescue HTTP::TimeoutError, HTTP::ConnectionError
      return []
    end
    return [] unless res.status.success?

    doc = Nokogiri::HTML(res.body.to_s)
    links = doc.css('a[href]').map { |a| a['href'].to_s }.uniq

    # Expected pattern: /q/queen/bohemian+rhapsody_20112599.html
    candidates = links.select { |h| h.match?(%r{^/[a-z]/[^/]+/[^/]+_\d+\.html$}i) }

    candidates.map do |href|
      full = href.start_with?('http') ? href : "#{BASE_URL}#{href}"
      begin
        uri = URI.parse(full)
        parts = uri.path.split('/').reject(&:empty?)
        # parts: [letter, artist_slug, title_id.html]
        artist_slug = parts[1].to_s
        title_id = parts[2].to_s
        title_slug = title_id.split('_').first.to_s
        artist_name = humanize_slug(artist_slug)
        track_name = humanize_slug(title_slug) + ' Lyrics'
      rescue
        next
      end
      next if artist_name.empty? || track_name.strip.empty?
      {
        'track' => {
          'track_name' => track_name,
          'artist_name' => artist_name,
          'track_id' => full
        }
      }
    end.compact
  end

  def fetch_lyrics(track_id)
    begin
      res = HTTP.follow(max_hops: 5).timeout(connect: 5, read: 10).headers(HEADERS).get(track_id)
    rescue HTTP::TimeoutError, HTTP::ConnectionError
      return ''
    end
    return '' unless res.status.success?

    doc = Nokogiri::HTML(res.body.to_s)
    # Lyrics content container
    node = doc.at_css('div#content.lyrictxt') || doc.at_css('.js-lyrics')
    return '' unless node
    # Normalize <br> to newlines and collapse whitespace
    node.inner_html.gsub(/<br\s*\/?>(\r?\n)?/i, "\n").gsub(/\r?\n[\t ]+/, "\n").strip
  end

  def can_handle_track_id?(track_id)
    begin
      uri = URI.parse(track_id.to_s)
    rescue URI::InvalidURIError
      return false
    end
    host = uri.host.to_s.downcase
    host.end_with?('lyricsfreak.com')
  end

  private

  def humanize_slug(slug)
    # Convert pluses and dashes to spaces, then titleize
    s = slug.to_s.tr('+', ' ').tr('-', ' ')
    s.split.map { |w| w[0] ? w[0].upcase + w[1..] : w }.join(' ')
  end
end


# BigLyrics.net service subclass
class BigLyricsService < LyricsService
  BASE_URL = 'https://www.biglyrics.net'
  HEADERS = {
    'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.9',
    'Referer' => 'https://www.biglyrics.net/'
  }

  def search(term, type: :song)
    return [] if term.nil? || term.strip.empty?

    # Prefer a search-engine fallback because biglyrics native search is inconsistent
    ddg_q = URI.encode_www_form_component("site:biglyrics.net #{term} lyrics")
    ddg_url = "https://duckduckgo.com/html/?q=#{ddg_q}"
    begin
      res = HTTP.follow(max_hops: 5).timeout(connect: 5, read: 6).headers(HEADERS).get(ddg_url)
    rescue HTTP::TimeoutError, HTTP::ConnectionError
      return []
    end
    return [] unless res.status.success?

    doc = Nokogiri::HTML(res.body.to_s)
    raw_links = doc.css('a[href]').map { |a| a['href'] }.compact.uniq
    matches = raw_links.flat_map do |href|
      if href.start_with?('https://www.biglyrics.net', 'http://www.biglyrics.net', 'https://biglyrics.net', 'http://biglyrics.net')
        [href]
      elsif href.start_with?('/l/?') || href.include?('uddg=')
        begin
          uri = URI.parse(href.start_with?('http') ? href : "https://duckduckgo.com#{href}")
          params = CGI.parse(uri.query.to_s)
          encoded = params['uddg']&.first
          decoded = encoded ? CGI.unescape(encoded) : nil
          decoded && decoded.start_with?('http') ? [decoded] : []
        rescue
          []
        end
      else
        []
      end
    end

    # Song page pattern: /{artist}_lyrics/{song}.html
    song_links = matches.select { |u| u =~ %r{^https?://(www\.)?biglyrics\.net/[^/]+_lyrics/[^/]+\.html$}i }.uniq

    song_links.map do |full|
      begin
        uri = URI.parse(full)
        parts = uri.path.split('/').reject(&:empty?)
        artist_folder = parts[0].to_s # e.g., frank_sinatra_lyrics
        song_slug = parts[1].to_s.sub(/\.html\z/i, '')
        artist_slug = artist_folder.sub(/_lyrics\z/i, '')
        artist_name = humanize_slug(artist_slug, sep: '_')
        track_name = humanize_slug(song_slug, sep: '_') + ' Lyrics'
      rescue
        next
      end
      next if artist_name.empty? || track_name.strip.empty?
      {
        'track' => {
          'track_name' => track_name,
          'artist_name' => artist_name,
          'track_id' => full
        }
      }
    end.compact
  end

  def fetch_lyrics(track_id)
    begin
      res = HTTP.follow(max_hops: 5).timeout(connect: 5, read: 10).headers(HEADERS).get(track_id)
    rescue HTTP::TimeoutError, HTTP::ConnectionError
      return ''
    end
    return '' unless res.status.success?

    doc = Nokogiri::HTML(res.body.to_s)
    node = doc.at_css('div#lyric > div') || doc.at_css('#lyric')
    return '' unless node
    node.inner_html.gsub(/<br\s*\/?>(\r?\n)?/i, "\n").gsub(/\r?\n[\t ]+/, "\n").strip
  end

  def can_handle_track_id?(track_id)
    begin
      uri = URI.parse(track_id.to_s)
    rescue URI::InvalidURIError
      return false
    end
    host = uri.host.to_s.downcase
    host.end_with?('biglyrics.net')
  end

  private

  def humanize_slug(slug, sep: '-')
    s = slug.to_s.tr(sep, ' ')
    s.split.map { |w| w[0] ? w[0].upcase + w[1..] : w }.join(' ')
  end
end


# ChartLyrics service subclass
class ChartLyricsService < LyricsService
  BASE_URL = 'http://api.chartlyrics.com/apiv1.asmx'
  HEADERS = {
    'User-Agent' => 'LogosLyrics/1.0 (Ruby HTTP Client)',
    'Accept' => 'application/xml, text/xml'
  }.freeze

  def initialize
    # ChartLyrics API doesn't require authentication currently,
    # but API key can be set via ENV['CHARTLYRICS_API_KEY'] if needed in future
    @api_key = ENV['CHARTLYRICS_API_KEY']
  end

  def search(term, type: :song)
    return [] if term.nil? || term.strip.empty?

    begin
      # Use SearchLyric endpoint to search for songs
      search_url = "#{BASE_URL}/SearchLyric"
      response = HTTP.timeout(connect: 5, read: 10).headers(HEADERS)
                     .get(search_url, params: { artist: '', song: term })
      
      return [] unless response.status.success?

      doc = Nokogiri::XML(response.body.to_s)
      results = []

      doc.css('SearchLyricResult').each do |result|
        song_id = result.at_css('LyricId')&.text
        checksum = result.at_css('LyricChecksum')&.text
        artist = result.at_css('Artist')&.text
        song = result.at_css('Song')&.text

        next if song_id.nil? || checksum.nil? || artist.nil? || song.nil?
        next if artist.strip.empty? || song.strip.empty?

        # Create a track_id that includes both song_id and checksum for lyrics fetching
        track_id = "#{song_id}|#{checksum}"

        results << {
          'track' => {
            'track_name' => song.strip,
            'artist_name' => artist.strip,
            'track_id' => track_id
          }
        }
      end

      results
    rescue HTTP::TimeoutError, HTTP::ConnectionError, Nokogiri::XML::SyntaxError => e
      # Log error if needed and return empty array
      []
    end
  end

  def fetch_lyrics(track_id)
    return '' if track_id.nil? || track_id.strip.empty?

    begin
      # Parse track_id to get song_id and checksum
      parts = track_id.split('|')
      return '' if parts.length != 2

      song_id, checksum = parts
      
      # Use GetLyric endpoint with proper parameters
      lyrics_url = "#{BASE_URL}/GetLyric"
      response = HTTP.timeout(connect: 5, read: 10).headers(HEADERS)
                     .get(lyrics_url, params: { lyricId: song_id, lyricCheckSum: checksum })
      
      return '' unless response.status.success?

      doc = Nokogiri::XML(response.body.to_s)
      lyric_text = doc.at_css('Lyric')&.text
      
      # Return empty string if no lyrics found or if lyrics indicate not available
      return '' if lyric_text.nil? || lyric_text.strip.empty? || lyric_text.strip == 'Not found'
      
      lyric_text.strip
    rescue HTTP::TimeoutError, HTTP::ConnectionError, Nokogiri::XML::SyntaxError => e
      ''
    end
  end

  def can_handle_track_id?(track_id)
    return false if track_id.nil? || track_id.strip.empty?
    
    # Check if track_id has the expected format: "song_id|checksum"
    parts = track_id.split('|')
    parts.length == 2 && !parts[0].empty? && !parts[1].empty?
  end
end
