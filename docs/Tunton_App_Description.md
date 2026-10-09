# Tunton

**Tagline:** Snap a Landmark. Find Your Way.

## App Description

**Tunton** is an AI-powered landmark recognition and navigation application that helps users discover famous landmarks and tourist attractions and find routes to or from them using photographs. Instead of relying solely on typing a place name, users can capture a landmark with their device's camera or choose an existing image from their gallery. Tunton analyzes the image using an **AI model that runs locally on the device** and matches it against a **landmark dataset bundled with the application**.

Once a landmark is identified, Tunton displays the recognized location and connects it with an interactive map powered by **Mapbox**. Users can save locations for future use and generate routes using a recognized landmark as either the **starting point** or the **destination**.

For example, a user can save a place they want to visit, upload an image of a landmark near them, and request directions from that recognized landmark to their saved destination. Alternatively, they can upload a photo of a landmark they want to visit and generate a route from their current GPS location or a manually selected starting point to the identified landmark.

Tunton combines **on-device AI recognition** with **map-based navigation** to make exploring landmarks more visual, intuitive, and convenient. Its core landmark recognition does not require cloud AI inference; map loading and route generation may require an internet connection.

## Core Features

### 1. AI-Powered Landmark Recognition
- Identifies supported famous landmarks and tourist attractions from images.
- Runs image recognition locally on the user's device.
- Uses AI model files and landmark reference data included directly in the application project.
- Recognition is limited to landmarks represented in the bundled dataset.

### 2. Camera and Gallery Upload
- Take a photograph of a landmark using the device camera.
- Select an existing landmark photo from the gallery.
- Use either image source for landmark recognition.

### 3. Mapbox Map and Navigation
- View identified landmarks on an interactive map.
- Generate routes between a chosen starting point and destination.
- Use Mapbox for the map and navigation-related functionality; internet connectivity may be needed for maps and routing.

### 4. Saved Locations
- Save preferred or frequently visited locations.
- Select a saved location as a route destination.

### 5. Two-Way Image-Based Routing

**Image as a starting point**
1. Upload or capture a photograph of a supported landmark.
2. Tunton identifies the landmark and its mapped location.
3. Choose a previously saved destination.
4. Generate a route from the recognized landmark to that destination.

**Image as a destination**
1. Upload or capture a photograph of a landmark you want to visit.
2. Tunton identifies the landmark and its mapped location.
3. Choose your current GPS location or manually select a starting point.
4. Generate a route to the recognized landmark.

> **Location note:** Recognizing a landmark in a photograph does not prove the user is physically at that landmark. When using a photograph as the route origin, the app treats the recognized landmark as the selected starting point—not as verified live GPS location.

## How Tunton Works

1. **Capture or upload:** The user supplies a landmark image through the camera or gallery.
2. **Recognize locally:** The on-device AI processes the image and compares it with the bundled landmark reference data.
3. **Identify the place:** Tunton retrieves the matching landmark's stored name and location information.
4. **Choose a route:** The user selects the landmark as their origin or destination and chooses the other endpoint from GPS, a map selection, or a saved location.
5. **Navigate:** Mapbox displays the relevant map and route when the required map/routing services are available.

## Local AI and Internet Requirements

| Function | Processing / dependency |
|---|---|
| Landmark image recognition | On-device AI model |
| Landmark reference dataset | Bundled locally with the application |
| Camera and gallery image selection | Device functionality |
| Map display | Mapbox; online resources may be required |
| Route generation | Mapbox; internet connectivity may be required |

**Tunton is a local-AI application, not necessarily a fully offline navigation application.** Its landmark recognition is designed to work without a cloud AI service, while its mapping and routing features depend on the Mapbox integration and available connectivity.

## What Makes Tunton Different?

Tunton turns an ordinary landmark photograph into a useful navigation input. Users can identify a destination visually, route **toward** a landmark shown in a photo, or route **from** a recognized landmark toward a saved place. By keeping landmark recognition on the device and bundling the recognition dataset with the app, Tunton reduces reliance on cloud-based image analysis.

## Short Description

**Tunton** is a local-AI-powered landmark recognition and navigation app that lets users photograph or upload images of famous landmarks, identify them on-device, and use the recognized locations as starting points or destinations for Mapbox-powered routes. Users can also save locations and navigate between identified landmarks, saved destinations, current GPS positions, and manually selected points.

## Hackathon Pitch

**Tunton transforms pictures into places—and places into routes.** With locally running AI and a built-in landmark dataset, users can identify supported tourist attractions through their camera or gallery without relying on cloud-based image recognition. Mapbox navigation then connects those recognized places to saved destinations or selected starting points, making tourism exploration more visual and convenient.
