'use strict';

$(document).ready(function() {
  class LyricsApp {
    constructor() {
      this.searchInput = $('#search-input');
      this.results = $('#results');
      this.lyricsDiv = $('#lyrics');
      this.init();
    }

    init() {
      this.lyricsDiv.hide();
      this.bindEvents();
    }

    bindEvents() {
      $('#search-form').on('submit', (e) => {
        e.preventDefault();
        this.performSearch();
      });
    }

    performSearch() {
      const term = this.searchInput.val().trim();
      if (!term) {
        this.clearResults();
        return;
      }
      $.getJSON(`/search?term=${encodeURIComponent(term)}`)
        .then(response => {
          if (response.success) {
            this.displayResults(response.results);
          } else {
            console.error('Error fetching data', response.error);
            this.results.text('An error occurred while searching.');
          }
        })
        .catch(error => {
          console.error('Error fetching data', error);
          this.results.text('An error occurred while searching.');
        });
    }

    clearResults() {
      this.results.empty();
      this.lyricsDiv.hide();
    }

    displayResults(tracks) {
      this.clearResults();
      if (tracks.length === 0) {
        this.results.text('No results found.');
        return;
      }

      tracks.forEach(track => {
        // Now 'track' is the standardized object {id, title, artist, service}
        const resultElement = $(`<li class="result">
          <span class="artist">${track.artist}</span> - <span class="title">${track.title}</span>
          <span class="service">(${track.service})</span>
        </li>`);
        resultElement.on('click', () => this.displayLyrics(track.id, track.service, track.artist, track.title));
        this.results.append(resultElement);
      });
    }

    displayLyrics(trackId, serviceName, artistName, trackName) {
      this.lyricsDiv.html('<h3>Loading...</h3>').show();
      $.getJSON(`/lyrics?track_id=${encodeURIComponent(trackId)}&service_name=${encodeURIComponent(serviceName)}`)
        .then(response => {
          if (response.success && response.lyrics) {
            const formattedLyrics = response.lyrics.replace(/\n/g, '<br/>');
            this.lyricsDiv.html(`<h3>${artistName} - ${trackName}</h3><p>${formattedLyrics}</p>`);
          } else {
            console.error('Error fetching lyrics', response.error);
            this.lyricsDiv.html(`<h3>Lyrics for ${artistName} - ${trackName} could not be loaded.</h3>`);
          }
        })
        .catch(error => {
          console.error('Error fetching lyrics', error);
          this.lyricsDiv.html(`<h3>Lyrics for ${artistName} - ${trackName} could not be loaded.</h3>`);
        });
    }
  }

  // Initialize the lyrics application
  const app = new LyricsApp();
});
