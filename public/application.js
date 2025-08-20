import { Application } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"
import LyricsController from "./controllers/lyrics_controller.js"

window.Stimulus = Application.start()
Stimulus.register("lyrics", LyricsController)
