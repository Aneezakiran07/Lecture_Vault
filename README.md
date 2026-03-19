# LectureVault

A Flutter Android app that organizes your lecture photos by subject automatically. Take a photo of your lecture notes, and the app figures out which subject it belongs to and saves it to the right folder.

---

## What it does

Students take a lot of lecture photos and they all end up in a single camera roll with no structure. LectureVault fixes that. You pick photos from your gallery or take them directly from the camera, and the app reads the text in them using OCR, sends that to Gemini AI to classify the subject, and copies the photo into the correct folder on your device.

User can also share the photo with others and can zoom in the photo. Basically, this can be the user own notes app also. He dont need to open the gallery or folders to see those photos. He can just read it from the app
Everything is stored locally.

---

## How it works

**1. OCR (Google ML Kit)**

Text recognition runs entirely on-device using Google ML Kit. No internet required for this step. On top of raw OCR output, there is an enhancer that corrects common recognition mistakes, strips noise words, extracts meaningful keywords, and detects academic patterns using regex rules — things like "derivative calculus" or "acid base chemistry".

**2. Classification (Gemini 3.1 Flash Lite)**

All OCR results from a batch of photos are sent to Gemini in a single request. Gemini returns a JSON array with a subject and confidence score for each photo. The prompt is structured so Gemini explains its reasoning before committing to a subject label, which significantly improves accuracy.

**3. Storage**

Photos are copied into folders named after your subjects. The folder structure lives at a path you choose during onboarding. Subject list and storage path are saved locally using SharedPreferences.

---

## Stack

- Flutter (Android)
- Google ML Kit Text Recognition
- Gemini 3.1 flash lite api
- SharedPreferences
- image_picker
- file_picker
- permission_handler
- path

---

## Getting started

**Prerequisites**

- Flutter SDK
- Android device or emulator (API 21+)
- Gemini API key (free tier works)

**Setup**

Clone the repo and install dependencies:

```bash
git clone https://github.com/Aneezakiran07/LectureVault
cd lecturevault
flutter pub get
```

Create a `.env` file in the project root:

```
GEMINI_API_KEY=your_key_here
```

Add `.env` as an asset in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - .env
```

Run on a connected device:

```bash
flutter run
```

---

## Project structure

```
lib/
├── main.dart
├── core/constants/
│   └── colors.dart
├── models/
│   ├── photo_item.dart
│   └── subject_folder.dart
├── screens/
│   ├── onboarding/folder_setup_screen.dart
│   ├── home/home_screen.dart
│   ├── upload/upload_screen.dart
│   ├── folder_view/folder_view_screen.dart
│   └── settings/settings_screen.dart
└── services/
    ├── storage_service.dart
    ├── permission_service.dart
    ├── ocr_service.dart
    ├── ocr_enhancer.dart
    ├── ocr_result.dart
    ├── classifier_service.dart
    └── gemini_classifier.dart
```

---

## Limitations

- The app is Android only for now.
- Gemini free tier is limited to 10 requests per minute. The current architecture sends one request per upload session regardless of photo count, so this should not be an issue in normal use. 
- Photos with very little or no readable text will be marked as Unclassified. But user can move them to any folder himself.

---

## Development approach

This was built incrementally, with each increment pushed as a separate branch on GitHub. The order was roughly: UI screens first with mock data, then persistent storage with SharedPreferences, then real photo upload and file copying, then folder view with real photos, then settings wired up, then OCR and Gemini.

### Please read this

The gemini model this project is using can send 500 requests per day. If a user send 20 or less photos per session to classify, it counts as one request only. So we can classify 20x500= 1000 photos per day(if we send 20 photos per session).
but if anyone not want to worry abput rate limiting, then he/she can clone my repo and use his/her own gemini key in the /env
---
