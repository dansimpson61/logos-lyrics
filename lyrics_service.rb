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

    # Normalize-based dedup and group by artist
    seen = {}
    grouped_results = results.each_with_object({}) do |item, hash|
      track = item['track'] || {}
      artist = String(track['artist_name']).strip
      title = String(track['track_name']).strip.downcase.gsub(/\s+lyrics\b/i, '')
      dedup_key = [artist.downcase, title]

      next if artist.empty? || title.empty? || seen[dedup_key]
      seen[dedup_key] = true

      (hash[artist] ||= []) << track
    end

    grouped_results.map do |artist_name, tracks|
      {
        'artist_name' => artist_name,
        'tracks' => tracks
      }
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
          'track_id' => track_url,
          'source' => 'SongLyrics'
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
          'track_id' => full,
          'source' => 'SongLyrics'
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
          'track_id' => full,
          'source' => 'SongLyrics'
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
          'track_id' => full,
          'source' => 'SongLyrics'
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
          'track_id' => full,
          'source' => 'LyricsFreak'
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
          'track_id' => full,
          'source' => 'BigLyrics'
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

  def search(term, type: :song)
    # Return hardcoded results for demonstration purposes
    [
      {
        'track' => {
          'track_name' => 'Yesterday',
          'artist_name' => 'The Beatles',
          'track_id' => 'yesterday-the-beatles'
        }
      },
      {
        'track' => {
          'track_name' => 'Let It Be',
          'artist_name' => 'The Beatles',
          'track_id' => 'let-it-be-the-beatles'
        }
      },
      {
        'track' => {
          'track_name' => 'Bohemian Rhapsody',
          'artist_name' => 'Queen',
          'track_id' => 'bohemian-rhapsody-queen'
        }
      }
    ]
  end

  def fetch_lyrics(track_id)
    # ChartLyrics API requires a checksum for GetLyric. This is a placeholder.
    # In a real application, you'd need to implement the checksum calculation.
    checksum = 'PLACEHOLDER_CHECKSUM' 
  response = HTTP.timeout(connect: 5, read: 10).get("#{BASE_URL}/GetLyric?lyricId=#{track_id}&lyricCheckSum=#{checksum}")
    return '' unless response.status.success?

    doc = Nokogiri::XML(response.body.to_s)
    doc.css('Lyric').text
  end

  def can_handle_track_id?(_track_id)
    false
  end
end
