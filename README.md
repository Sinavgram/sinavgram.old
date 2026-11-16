# Sınavgram – Legacy Flutter Application

**Sınavgram** is an interactive exam preparation and learning platform designed to help students study, practice, and improve their academic performance.

This repository contains an earlier Flutter-based implementation of the Sınavgram client application. It provides a cross-platform foundation for accessing the platform's educational services through a unified application.

> **Project Status:** Legacy / Archived implementation. This repository is maintained as part of the project's development history and may not reflect the current application architecture.

## Overview

Sınavgram aims to provide students with a centralized learning environment where they can access educational content, interact with questions, and manage their exam preparation activities.

The application is developed using Flutter and Dart, allowing the same codebase to target multiple operating systems.

## Supported Platforms

The repository includes platform-specific project configurations for:

- Android
- iOS


## Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application framework |
| Dart | Primary programming language |
| Provider | State management |
| HTTP | Backend API communication |
| Shared Preferences | Local preference storage |
| Cached Network Image | Image loading and caching |
| Image Picker | Image selection |
| Photo View | Image viewing |
| Syncfusion PDF Viewer | PDF document viewing |
| Flutter Markdown | Markdown rendering |
| Google Mobile Ads | Advertisement integration |
| Flutter Local Notifications | Local notifications |
| App Links | Deep linking |
| URL Launcher | External URL handling |
| File Saver | File saving |
| Share Plus | Native sharing functionality |

## Key Components

### Backend Communication
- HTTP-based API communication.
- Integration with the Sınavgram backend.
- Network-based data retrieval and submission.

### Content & Media
- Network image loading and caching.
- Image selection and viewing.
- PDF document rendering.
- Markdown content support.
- File saving and sharing.

### Application Services
- Local preference management.
- Deep link handling.
- Local notification support.
- Timezone-aware notification scheduling.
- External URL launching.
- Advertisement integration.

### State Management
The application uses Provider for state management, helping separate application state from the user interface.

## Project Structure

```text
sinavgram.old/
│
├── android/          # Android platform configuration
├── ios/              # iOS platform configuration
├── linux/            # Linux platform configuration
├── macos/            # macOS platform configuration
├── windows/          # Windows platform configuration
├── web/              # Web platform configuration
│
├── lib/              # Main Dart application source
├── test/             # Application tests
│
├── pubspec.yaml      # Project dependencies and metadata
├── pubspec.lock      # Locked dependency versions
├── analysis_options.yaml
└── README.md
```

## Requirements

To work with this project, you need:

- Flutter SDK
- Dart SDK (included with Flutter)
- Git
- An appropriate development environment for your target platform

The project currently specifies the following Dart SDK constraint:

```yaml
environment:
  sdk: ^3.8.1
```

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/mehmetalper04/sinavgram.old.git

cd sinavgram.old
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Check the Flutter environment

```bash
flutter doctor
```

### 4. Run the application

For the default development target:

```bash
flutter run
```

To specify a target platform:

```bash
flutter run -d chrome
```

Other available devices can be listed using:

```bash
flutter devices
```

## Building

Flutter supports building the application for different platforms.

Examples:

**Android**
```bash
flutter build apk
```

**iOS**
```bash
flutter build ios
```


Platform-specific build requirements still apply. For example, iOS builds require macOS and the appropriate Apple development tools.

## Related Repository

The client application communicates with the Sınavgram backend.

- [Sınavgram Backend (Legacy)](https://github.com/mehmetalper04/sinavgram.backend.old)

## Development Notes

This repository represents an earlier stage of Sınavgram's development.

Some dependencies, platform configurations, and implementation details may be outdated. Compatibility with current Flutter and Dart releases is not guaranteed.

The project should primarily be considered a historical codebase and a reference for the evolution of the Sınavgram application.

## License

No license has been specified for this repository. Please contact the repository owner before redistributing or reusing the source code.

## Author

**Mehmet Alper Kocaoğlu**

- GitHub: [@mehmetalper04](https://github.com/mehmetalper04)
- Repository: [sinavgram.old](https://github.com/mehmetalper04/sinavgram.old)

---

*Part of the Sınavgram educational platform project.*
