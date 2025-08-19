# Lyrics Search Web Application

This is a simple web application that allows users to search for song lyrics. Users can enter a song title or artist name to find relevant tracks and then view the lyrics for a selected song.

The app should exemplify the ideas outlined in our Ode to Joy document.

 Here is a summary of the task and my thinking so far.

Project Title: Revive and Enhance the "Logos" Lyrics Application

High-Level Goal: The project's objective is to build a robust and resilient web application that discovers and displays beautifully formatted, complete song lyrics. A core principle is to avoid dependency on any single provider and to source lyrics from a diverse range of websites, including those that host obscure, old, or niche music, while respecting copyright.

Initial State of the Project:

The codebase is a simple Ruby/Sinatra application.
The backend features an adapter pattern (LyricsService) for fetching lyrics and exposes two API endpoints: /search and /lyrics.
The original implementation used the Musixmatch API, but the API key was hardcoded.
An implementation for a second service, Lyrics.ovh, was present but commented out.
Key Discoveries and Decisions:

Assessment of Existing Providers:

Musixmatch: After reviewing the terms of service, I concluded that they were too restrictive, particularly concerning commercial use and data ownership.
Lyrics.ovh: I determined that this service is defunct and no longer operational.
Architectural Strategy:

I decided to embrace and expand the existing adapter pattern. My plan is to create a central "service manager" that can query multiple lyric providers (adapters) simultaneously. This architecture will make the application highly extensible and resilient, as it won't be reliant on any single source.
Investigation of New Lyric Sources:


Discovery and Integration Strategy:

Discovery: I formulated a strategy to discover new lyric sources. This involves using diverse search queries (for popular, old, and niche songs) to identify a wide range of potential lyric websites. This process would be semi-automated, with a manual vetting step to assess the quality and breadth of each source before building an adapter for it.
Integration: For each new source, a dedicated adapter class will be created. This adapter will function as a web scraper, tailored to the specific HTML structure of that site.


Desired End State: The final deliverable should be a fully functional lyrics search application that:

Exemplifies our Ode to Joy philosophy.
Is built on a flexible, multi-provider architecture.
Includes multiple working lyric provider adapters.
Has a clear framework for easily adding new adapters in the future.
Follows best practices, such as using environment variables for API keys and other secrets.
I hope this detailed summary is helpful for the next steps.


The ones we've identified together so far are:

azlyrics.com
biglyrics.net
songlyrics.net
www.streetdirectory.com/lyricadvisor/
To expand on this, here are several other potential sources we could build adapters for. These sites have different strengths; some are better for popular music, while others excel at older or more obscure tracks, which aligns with our goal of having a diverse and comprehensive collection.

Potential Lyric Sources:

AZLyrics (azlyrics.com): One of the oldest and most popular lyric sites. It has a vast library, including many older songs, and is known for its accuracy. The HTML structure is relatively clean, which makes it a good candidate for scraping.

SongLyrics (songlyrics.com): Another large, well-established database. It often has user-submitted corrections, which can be a double-edged sword (potentially more accurate, but also more prone to errors).

LyricsFreak (lyricsfreak.com): This site has a large collection and often includes album track listings, which could be useful for finding related songs.

MetroLyrics (metrolyrics.com): Known for its partnership with Gracenote, which means it has a large, licensed catalog. The site was officially discontinued but is archived and still accessible, making it a potential source for older, hard-to-find lyrics that might not be on newer sites.

DarkLyrics (darklyrics.com): This is a great example of a niche-specific source. It specializes in metal (death, black, etc.) and is often the only place to find lyrics for underground bands in those genres. This is a perfect candidate for our strategy of including specialized sources.

Lyrics.com: A comprehensive resource that often includes metadata about songs, such as year, genre, and writers, which could be valuable for the application in the future.

Strategy for Integration:

For each of these sites, the plan would be the same: create a dedicated adapter that can search the site and scrape the lyrics from the song's page. By building a collection of these adapters, the "Logos" app can draw from a wide variety of sources, making it incredibly resilient and comprehensive. We could prioritize building adapters for the sites that seem most promising and have the easiest-to-scrape HTML structures.