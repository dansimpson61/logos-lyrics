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
      // Attach event listener to search form to prevent default form submission
      $('#search-form').on('submit', (e) => {
        e.preventDefault();
        this.performSearch();
      });

      // Optional: Listen for input events as well for instant search (debounced)
      // this.searchInput.on('input', debounce(this.performSearch.bind(this), 500));
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
          }
        })
        .catch(error => console.error('Error fetching data', error));
    }

    clearResults() {
      this.results.empty();
    }

    displayResults(tracks) {
      this.clearResults();
      tracks.forEach(track => {
        const item = track.track;
        const resultElement = $(`<li class="result">${item.artist_name} - ${item.track_name}</li>`);
        resultElement.on('click', () => this.displayLyrics(item.track_id, item.artist_name, item.track_name));
        this.results.append(resultElement);
      });
    }

    displayLyrics(trackId, artistName, trackName) {
      $.getJSON(`/lyrics?track_id=${trackId}`)
        .then(response => {
          if (response.success) {
            this.lyricsDiv.html(`<h3>${artistName} - ${trackName}</h3><p>${response.lyrics.replace(/\n/g, '<br/>')}</p>`).show();
          } else {
            console.error('Error fetching lyrics', response.error);
          }
        })
        .catch(error => console.error('Error fetching lyrics', error));
    }
  }

  // Initialize the lyrics application
  const app = new LyricsApp();
});


// class LyricsService {
//   constructor(apiKey) {
//     this.apiKey = apiKey;
//     this.baseUrl = ''; // This will be set by subclasses
//   }

//   search(term) {
//     throw new Error('Search method must be implemented by subclasses');
//   }

//   fetchLyrics(trackId) {
//     throw new Error('FetchLyrics method must be implemented by subclasses');
//   }
// }

// class MusixmatchService extends LyricsService {
//   constructor(apiKey) {
//     super(apiKey);
//     this.baseUrl = 'https://api.musixmatch.com/ws/1.1/';
//   }

//   search(term) {
//     const url = `${this.baseUrl}track.search?q=${encodeURIComponent(term)}&page_size=10&page=1&s_track_rating=desc&apikey=${this.apiKey}`;
//     return $.getJSON(url).then(response => response.message.body.track_list.filter(track => track.track.has_lyrics));
//   }

//   fetchLyrics(trackId) {
//     const url = `${this.baseUrl}track.lyrics.get?track_id=${trackId}&apikey=${this.apiKey}`;
//     return $.getJSON(url).then(response => response.message.body.lyrics.lyrics_body);
//   }
// }

// class LyricsApp {
//   constructor(lyricsService) {
//     this.lyricsService = lyricsService;
//     this.searchInput = $('#search-input');
//     this.results = $('#results');
//     this.lyricsDiv = $('#lyrics');
//     this.init();
//   }

//   init() {
//     this.lyricsDiv.hide();
//     this.bindEvents();
//   }

//   bindEvents() {
//     this.searchInput.on('input', () => {
//       const term = this.searchInput.val().trim();
//       if (!term) {
//         this.clearResults();
//         return;
//       }
//       this.lyricsService.search(term)
//         .then(tracks => this.displayResults(tracks))
//         .catch(error => console.error('Error fetching data', error));
//     });
//   }

//   clearResults() {
//     this.results.empty();
//   }

//   displayResults(tracks) {
//     this.clearResults();
//     tracks.forEach(track => {
//       const item = track.track;
//       const resultElement = $(`<li class="result">${item.artist_name} - ${item.track_name}</li>`);
//       resultElement.on('click', () => this.displayLyrics(item.track_id, item.artist_name, item.track_name));
//       this.results.append(resultElement);
//     });
//   }

//   displayLyrics(trackId, artistName, trackName) {
//     this.lyricsService.fetchLyrics(trackId)
//       .then(lyrics => {
//         this.lyricsDiv.html(`<h3>${artistName} - ${trackName}</h3><p>${lyrics.replace(/\n/g, '<br/>')}</p>`).show();
//       })
//       .catch(error => console.error('Error fetching lyrics', error));
//   }
// }

// // Example usage:
// const apiKey = 'f5c171c61c448f24f1f333cd7ee51019';
// const musixmatchService = new MusixmatchService(apiKey);
// const app = new LyricsApp(musixmatchService);
