# Lyrics Search Web Application

This is a simple web application that allows users to search for song lyrics using the Musixmatch API. Users can enter a song title or artist name to find relevant tracks and then view the lyrics for a selected song.

## Features

*   Search for songs or artists.
*   View a list of matching tracks.
*   Display lyrics for a selected track.
*   Responsive design for different screen sizes (basic).

## Technologies Used

*   **Backend:**
    *   Ruby
    *   Sinatra (web framework)
    *   Puma (web server)
*   **Frontend:**
    *   HTML
    *   CSS
    *   JavaScript
    *   jQuery
*   **API:**
    *   Musixmatch API (for lyrics)
*   **Package Management:**
    *   Bundler (for Ruby gems)

## Setup and Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```
    (Replace `<repository_url>` and `<repository_directory>` with the actual URL and directory name)

2.  **Install Ruby dependencies:**
    Make sure you have Ruby and Bundler installed. Then run:
    ```bash
    bundle install
    ```

3.  **API Key:**
    This project uses the Musixmatch API. The API key is currently hardcoded in `lyrics_service.rb`.
    ```ruby
    # lyrics_service.rb
    # ...
    # class MusixmatchService < LyricsService
    # API_KEY = 'f5c171c61c448f24f1f333cd7ee51019' # Replace with your key if needed
    # ...
    ```
    Ideally, this should be configured using an environment variable.

4.  **Run the application:**
    You can start the Sinatra web server using:
    ```bash
    ruby app.rb
    ```
    The application will typically be available at `http://localhost:4567` in your web browser.

## Usage

1.  Once the application is running (see "Setup and Installation"), open your web browser and navigate to `http://localhost:4567` (or the address shown when you started the server).
2.  You will see a search bar. Type the name of a song or an artist you are interested in.
3.  Click the "Search" button or press Enter.
4.  A list of matching tracks will appear below the search bar.
5.  Click on any track in the list to view its lyrics. The lyrics will be displayed in a section on the page.

## API Endpoints

The backend provides the following API endpoints:

*   `GET /search`
    *   **Description:** Searches for tracks based on a query term.
    *   **Query Parameters:**
        *   `term` (string, required): The search term (song title or artist name).
    *   **Success Response (JSON):**
        ```json
        {
          "success": true,
          "results": [
            {
              "track": {
                "track_id": 12345,
                "track_name": "Song Name",
                "artist_name": "Artist Name",
                "has_lyrics": 1
                // ... other track details
              }
            }
            // ... more tracks
          ]
        }
        ```
    *   **Error Response (JSON):**
        ```json
        {
          "success": false,
          "error": "Error message"
        }
        ```

*   `GET /lyrics`
    *   **Description:** Fetches the lyrics for a specific track ID.
    *   **Query Parameters:**
        *   `track_id` (string/integer, required): The ID of the track from the Musixmatch API.
    *   **Success Response (JSON):**
        ```json
        {
          "success": true,
          "lyrics": "Line 1 of lyrics\nLine 2 of lyrics\n..."
        }
        ```
    *   **Error Response (JSON):**
        ```json
        {
          "success": false,
          "error": "Error message"
        }
        ```

## Project Structure

```
.
├── app.rb                     # Main Sinatra application file (routes, request handling)
├── Gemfile                    # Ruby dependencies for Bundler
├── Gemfile.lock               # Locked versions of Ruby dependencies
├── lyrics_service.rb          # Service classes for fetching lyrics from APIs
├── public/                    # Static assets (HTML, CSS, JavaScript)
│   ├── index.html             # Main HTML page for the application
│   ├── logos.css              # Stylesheet for the application
│   └── logos.js               # Frontend JavaScript for search and lyrics display
├── views/                     # (Currently contains an 'api keys' file, purpose might be for notes)
│   └── api keys
├── README.md                  # This file
└── generate-app-structure.sh  # Script to generate app_structure_and_contents.txt (dev utility)
└── app_structure_and_contents.txt # Text file with project structure (dev utility)

```

*   `app.rb`: The core Sinatra application file. It defines routes, handles incoming requests, and interacts with the `lyrics_service` to fetch data.
*   `lyrics_service.rb`: Contains classes (`MusixmatchService`, `LyricsOvhService`) responsible for communicating with external lyrics APIs.
*   `public/`: This directory holds all static files served to the client:
    *   `index.html`: The single HTML page for the application.
    *   `logos.css`: Contains the CSS styles.
    *   `logos.js`: Handles frontend logic, including making AJAX calls to the backend for search and lyrics.
*   `Gemfile` / `Gemfile.lock`: Manage the project's Ruby gem dependencies.
*   `views/`: Typically used for server-side templates in Sinatra. Its current usage for 'api keys' might be for developer notes.
*   `generate-app-structure.sh` & `app_structure_and_contents.txt`: Developer utilities, likely for understanding or documenting the codebase structure.

## TODO

This is a list of potential improvements and features for the future:

*   **Secure API Key Management:**
    *   Move the Musixmatch API key from being hardcoded in `lyrics_service.rb` to an environment variable (e.g., using `ENV['MUSIXMATCH_API_KEY']`).
    *   Update setup instructions to reflect this change.
*   **Implement Lyrics.ovh Service:**
    *   The `LyricsOvhService` class is present in `lyrics_service.rb` but commented out in `app.rb`.
    *   Uncomment and fully integrate it as an alternative lyrics provider.
    *   Potentially add a mechanism (e.g., UI toggle or configuration) to switch between lyrics services.
*   **Error Handling and Frontend Feedback:**
    *   Improve how errors from API calls are displayed to the user on the frontend (e.g., user-friendly messages instead of just console logs).
    *   Provide clearer loading indicators during API requests.
*   **Testing:**
    *   Add unit tests for the backend (e.g., for `app.rb` routes and `lyrics_service.rb` logic) using a framework like RSpec.
    *   Consider adding integration tests for the API endpoints.
    *   Frontend JavaScript tests could also be beneficial.
*   **UI/UX Enhancements:**
    *   Improve the visual design and user experience of the application.
    *   Consider features like pagination for search results if many tracks are returned.
*   **Code Refinements:**
    *   Review and refactor code for clarity, efficiency, and best practices.
    *   Remove or clean up commented-out code and unused files (e.g., `public/logos.js_bak`, `public/search.js_bak`).
*   **Contributing Guidelines:**
    *   Add a `CONTRIBUTING.md` file with instructions for developers who want to contribute to the project.
*   **License:**
    *   Add a `LICENSE` file to specify how the project can be used and distributed (e.g., MIT, Apache 2.0).
*   **Cross-Origin Resource Sharing (CORS):**
    *   The `Rack::Cors` middleware is in `app.rb` but currently commented out. If the frontend were to be served from a different domain or port than the backend in some deployment scenarios, this would need to be configured and enabled.
