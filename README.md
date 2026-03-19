# LectureVault

A Flutter Android app that automatically organizes your lecture photos by subject. Screenshot a slide, a ChatGPT explanation, a textbook page, or a whiteboard — LectureVault reads it and files it into the right folder instantly.

---

## The problem

You screenshot lecture slides, type out notes, grab explanations from ChatGPT, photograph textbook pages and all of it ends up in one chaotic camera roll. Finding anything later is a nightmare.

LectureVault fixes that. Every photo goes into the right subject folder automatically, without you having to think about it.

---

## What it works best on

**Digital screenshots** are where LectureVault shines:
- Lecture slides and presentation screenshots
- ChatGPT / AI tool explanations
- Textbook and PDF page photos
- Typed notes and study guides
- Website and article screenshots

**Printed and neat handwritten notes** are also well supported - the OCR pipeline handles clean text reliably.

> Heavily cursive or very messy handwriting is best effort, classification still works when enough keywords are readable, but digital content gives the most consistent results.

---

## How it works

**1. OCR — Google ML Kit (on-device)**

Text recognition runs entirely on your device. No internet required for this step. On top of raw OCR output, an enhancer layer corrects common recognition mistakes, strips noise words, extracts meaningful keywords, and detects academic patterns using regex , things like `derivative calculus`, `acid base chemistry`, or `supply demand economics`.

**2. Classification — Gemini Flash**

All OCR results from a batch of photos are sent to Gemini in a single request. Gemini returns a subject and confidence score for each photo. The prompt is structured so Gemini reasons through the content before committing to a label, this significantly improves accuracy on ambiguous content.

**3. Storage — fully local**

Photos are copied into folders named after your subjects. The folder structure lives wherever you choose during onboarding. Your subject list and storage path are saved locally using SharedPreferences. Nothing leaves your device except the OCR text sent to Gemini for classification.

---

## It's also a notes viewer

You don't need to open your gallery or file manager to read your notes. LectureVault lets you browse, zoom into, and share any photo directly from inside the app. Think of it as your own organized notes app, just one that files everything for you automatically.

---

## Stack

- Flutter (Android)
- Google ML Kit Text Recognition
- Gemini Flash API (free tier)
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
- Gemini API key [get one free at ai.google.dev](https://ai.google.dev), no credit card required

**Setup**

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

## Rate limits — not really a concern

Gemini's free tier allows 500 requests per day. LectureVault batches an entire upload session into **one request** regardless of photo count — so 20 photos = 1 request. That's up to 10,000 photos classified per day on the free tier.

If you want your own independent quota, just clone the repo and drop your own Gemini key in `.env`.

---

## Limitations

- Android only for now.
- Photos with very little readable text (blank pages, pure diagrams) are marked Unclassified, you can manually move them to any folder.
- Gemini classification requires an internet connection. OCR runs offline.

---

## Development approach

Built incrementally with each increment pushed as a separate branch. Order was: UI screens with mock data → SharedPreferences storage → real photo upload and file copying → folder view → settings → OCR pipeline → Gemini classification.