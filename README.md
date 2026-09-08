[English](README.md) | [中文](README_zh.md)

# Shaarli Android

Shaarli Android is a lightweight, user-friendly Android client designed for the [Shaarli](https://github.com/shaarli/Shaarli) bookmarking service. Whether you want to quickly save a webpage or efficiently manage your bookmarks, this app provides a seamless experience.

## ✨ Features

*   **Quick Share**: Easily save links to your Shaarli instance from any app (e.g., browser, news client) by simply using the "Share" button.
*   **Open in browser**: For apps that don't have a "share" button but have an "open in browser" option, the app registers itself as a browser to capture the link. The captured link opens a prefilled "Add Item" page where you can review and save it.
*   **Manual Add**: In addition to sharing, you can also manually add links or create notes within the app. The app will automatically fetch the title and description for links, saving you the trouble of manual entry.
*   **Comprehensive Bookmark Management**:
    *   **View & Search**: Browse all your bookmarks on the main page and use the powerful search function to quickly find what you need. You can filter by keyword, tags, or visibility (public/private).
    *   **Edit & Delete**: Long-press any bookmark to enter edit mode, where you can modify its title, description, tags, or privacy status. A simple left swipe allows for easy deletion.
    *   **Quick Tag Search**: Tap on a tag within a bookmark to instantly find all other links sharing that tag.
*   **Secure & Reliable**: Your Shaarli server address and API Secret are stored securely and encrypted on your device, ensuring your account information is safe.
*   **Lightweight & Efficient**: We are committed to keeping the app lightweight by minimizing dependencies, offering you a tool that is small in size, low on resource consumption, and highly responsive.

## 🚀 How to Use

### First-Time Setup
1.  Open the app and tap the **Settings** icon in the top-right corner of the main screen.
2.  Enter your Shaarli **Server Address** (e.g., `https://myshaarli.domain.com`) and **API Secret**.
3.  Set the default privacy status for your links (private or public) according to your preference.
4.  Tap **Save**. Once configured, you're ready to go!

### Daily Sharing
1.  In your browser or another app, find a webpage you want to save.
2.  Tap the system's **Share** button.
3.  Select **Shaarli Android** from the share menu.
4.  The app will automatically save the link in the background and show a success notification. The whole process happens without you ever leaving the current app!



## 🛠️ For Developers

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

### Building the Application

To build the APK, run the following command:

```bash
flutter build apk --no-tree-shake-icons --split-per-abi
```

This will generate separate APKs for different CPU architectures. You can find the generated APKs in the `build/app/outputs/flutter-apk/` directory.

### Release Signing

By default, release APKs are signed with the debug keystore (fine for local testing and CI artifacts). To produce properly signed releases, create `android/key.properties` describing your keystore:

```properties
storeFile=/absolute/path/to/your-release-key.jks
storePassword=yourStorePassword
keyAlias=yourAlias
keyPassword=yourKeyPassword
```

The Gradle build picks this file up automatically; without it, release builds fall back to debug signing. Never commit `key.properties` or the keystore itself.

## ⚠️ Disclaimer

This project was largely generated with the assistance of Google's Gemini. The author had no prior experience in Android or Flutter development before undertaking this project. The primary goal was to explore the capabilities of AI-assisted development.

As a result, while the core functionalities have been implemented on the Android platform, the code has not been exhaustively tested and may contain bugs or unforeseen issues. Please use it with this understanding.

## 🤝 Feedback & Contribution

We welcome all forms of feedback and suggestions! If you encounter any issues or have any feature requests, please feel free to let us know via [GitHub Issues](https://github.com/k997/shaarli_android/issues).