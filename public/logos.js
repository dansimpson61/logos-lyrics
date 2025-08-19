'use strict';

document.addEventListener('DOMContentLoaded', () => {
  class LyricsApp {
    constructor() {
      this.searchInput = document.getElementById('search-input');
      this.results = document.getElementById('results');
      this.lyricsDiv = document.getElementById('lyrics');
      this.loader = document.querySelector('.loader');
      this.init();
    }

    init() {
      this.lyricsDiv.style.display = 'none';
      this.bindEvents();
    }

    bindEvents() {
      document.getElementById('search-form').addEventListener('submit', (e) => {
        e.preventDefault();
        this.performSearch();
      });
    }

    performSearch() {
      const term = this.searchInput.value.trim();
      if (!term) {
        this.clearResults();
        return;
      }
      this.loader.style.display = 'block';
      this.results.style.display = 'none';
      fetch(`/search?term=${encodeURIComponent(term)}`)
        .then(response => response.json())
        .then(data => {
          this.loader.style.display = 'none';
          this.results.style.display = 'block';
          if (data.success) {
            this.displayResults(data.results);
          } else {
            console.error('Error fetching data', data.error);
          }
        })
        .catch(error => {
          this.loader.style.display = 'none';
          this.results.style.display = 'block';
          console.error('Error fetching data', error)
        });
    }

    clearResults() {
      this.results.innerHTML = '';
    }

    displayResults(tracks) {
      this.clearResults();
      tracks.forEach(track => {
        const item = track.track;
        const resultElement = document.createElement('li');
        resultElement.className = 'result';
        resultElement.textContent = `${item.artist_name} - ${item.track_name}`;
        resultElement.addEventListener('click', () => this.displayLyrics(item.track_id, item.artist_name, item.track_name));
        this.results.appendChild(resultElement);
      });
    }

    displayLyrics(trackId, artistName, trackName) {
      this.loader.style.display = 'block';
      this.lyricsDiv.style.display = 'none';
  fetch(`/lyrics?track_id=${encodeURIComponent(trackId)}`)
        .then(response => response.json())
        .then(data => {
          this.loader.style.display = 'none';
          this.lyricsDiv.style.display = 'block';
          if (data.success) {
            this.lyricsDiv.innerHTML = `<h3>${artistName} - ${trackName}</h3><p>${data.lyrics.replace(/\n/g, '<br/>')}</p>`;
            this.lyricsDiv.style.display = 'block';
          } else {
            console.error('Error fetching lyrics', data.error);
          }
        })
        .catch(error => {
          this.loader.style.display = 'none';
          this.lyricsDiv.style.display = 'block';
          console.error('Error fetching lyrics', error)
        });
    }
  }

  // Initialize the lyrics application
  const app = new LyricsApp();
});