# Shaarli Android

This is a Flutter-based Android client for the Shaarli bookmarking service.

## Features

*   Share links from other apps to Shaarli.
*   Manage your Shaarli bookmarks.
*   Securely store your Shaarli instance credentials.

## Getting Started

### Prerequisites

*   Flutter SDK: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
*   Android Studio or VS Code with the Flutter plugin.

### Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/k997/shaarli_android.git
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```

## Building the Application

To build the APK, run the following command:

```bash
flutter build apk --no-tree-shake-icons --split-per-abi
```

This will generate separate APKs for different CPU architectures. You can find the generated APKs in the `build/app/outputs/flutter-apk/` directory.