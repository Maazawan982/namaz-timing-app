# Namaz Timing App with API & Instant Alerts

A feature-rich Flutter application designed to calculate accurate local prayer times using external APIs, featuring robust real-time notifications and alarm alerts to ensure users never miss a prayer.

## Core Features

* **Aladhan API Integration:** Dynamically fetches accurate, location-based schedules for all 5 daily prayers utilizing the Aladhan REST API.
* **Manual Testing Controls:** Includes a built-in time override system that allows developers to manually change and adjust prayer times to easily test if the app works correctly.
* **Smart Time Matching:** Actively monitors the local device clock to instantly fire a response the moment the current time matches a scheduled prayer.
* **Push Notifications:** Leverages system alerts to send immediate visible push notifications on the user's screen when it is time to pray.
* **Alarm Audio Ringing:** Rings a dedicated audio alert simultaneously with the notifications to capture user attention, even when the app is running in the background.

## Architecture & Tech Stack

* **Framework:** Flutter & Dart for cross-platform rendering and performance.
* **API Client:** Specialized service class for parsing JSON data from geolocation endpoints.
* **Local Notifications:** Advanced background channel management for high-importance audio alerts and heads-up notification banners.
* **State Management:** Clean separation between the User Interface (UI), background alarm services, and network utilities.
