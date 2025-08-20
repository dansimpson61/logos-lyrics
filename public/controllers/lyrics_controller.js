import { Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"

export default class extends Controller {
  static targets = [ "input", "results", "lyrics", "loader", "resultTemplate" ]

  async search(event) {
    event.preventDefault()
    const query = this.inputTarget.value
    if (!query) return

    this.lyricsTarget.innerHTML = ""
    this.resultsTarget.innerHTML = ""
    this.loaderTarget.style.display = "block"

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
    const resultItem = event.target.closest(".result-item")
    if (!resultItem || !resultItem.dataset.trackId) return

    this.lyricsTarget.textContent = "Loading lyrics..."
    const trackId = resultItem.dataset.trackId

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
    results.forEach(item => {
      const resultClone = this.resultTemplateTarget.content.cloneNode(true)
      const resultElement = resultClone.querySelector(".result-item")
      resultElement.dataset.trackId = item.track.track_id
      resultElement.querySelector(".artist-name").textContent = item.track.artist_name
      resultElement.querySelector(".track-name").textContent = item.track.track_name
      this.resultsTarget.appendChild(resultClone)
    })
  }
}
