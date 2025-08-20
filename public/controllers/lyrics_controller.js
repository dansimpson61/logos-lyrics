import { Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"

export default class extends Controller {
  static targets = [ "input", "results", "lyrics", "loader", "artistTemplate", "trackTemplate", "searchPanel" ]

  togglePanel() {
    this.searchPanelTarget.classList.toggle("is-expanded")
    if (this.searchPanelTarget.classList.contains("is-expanded")) {
      this.inputTarget.focus()
    }
  }

  async search(event) {
    event.preventDefault()
    const query = this.inputTarget.value
    if (!query) {
      this.#hideResults()
      return
    }

    this.lyricsTarget.innerHTML = ""
    this.resultsTarget.innerHTML = ""
    this.loaderTarget.style.display = "block"
    this.resultsTarget.style.display = "block"

    try {
      const response = await fetch(`/search?term=${encodeURIComponent(query)}`)
      const data = await response.json()
      this.loaderTarget.style.display = "none"

      if (data.success && data.results.length > 0) {
        this.#renderResults(data.results)
      } else {
        this.resultsTarget.innerHTML = "<li class='result-item'>No results found.</li>"
      }
    } catch (error) {
      this.loaderTarget.style.display = "none"
      this.resultsTarget.innerHTML = "<li class='result-item'>Search failed. Please try again.</li>"
      console.error("Search error:", error)
    }
  }

  async select(event) {
    const resultItem = event.currentTarget
    const { trackId, artistName, trackName } = resultItem.dataset
    if (!trackId) return

    this.inputTarget.value = `${artistName} - ${trackName}`
    this.searchPanelTarget.classList.remove("is-expanded")
    this.#hideResults()

    this.lyricsTarget.textContent = "Loading lyrics..."
    try {
      const response = await fetch(`/lyrics?track_id=${encodeURIComponent(trackId)}`)
      const lyricsData = await response.json()

      if (lyricsData.success) {
        this.lyricsTarget.textContent = lyricsData.lyrics
      } else {
        this.lyricsTarget.textContent = `Error: ${lyricsData.error}`
      }
    } catch (e) {
      this.lyricsTarget.textContent = "Failed to load lyrics."
      console.error("Lyrics fetch error:", e)
    }
  }

  #renderResults(results) {
    this.resultsTarget.innerHTML = ""
    results.forEach(artistGroup => {
      const artistClone = this.artistTemplateTarget.content.cloneNode(true)
      const artistHeading = artistClone.querySelector("h3")
      artistHeading.textContent = artistGroup.artist_name

      const trackList = artistClone.querySelector("ul")
      artistGroup.tracks.forEach(track => {
        const trackClone = this.trackTemplateTarget.content.cloneNode(true)
        const trackElement = trackClone.querySelector(".result-item")
        trackElement.dataset.trackId = track.track_id
        trackElement.dataset.artistName = artistGroup.artist_name
        trackElement.dataset.trackName = track.track_name

        trackClone.querySelector(".track-name-text").textContent = track.track_name
        trackClone.querySelector(".source-icon").classList.add(track.source.toLowerCase())

        trackList.appendChild(trackClone)
      })

      this.resultsTarget.appendChild(artistClone)
    })
  }

  #hideResults() {
    this.resultsTarget.style.display = "none"
    this.resultsTarget.innerHTML = ""
  }
}
