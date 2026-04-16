# LectureVault

A Flutter Android app that automatically organizes your lecture photos by subject, lets you search every word inside them, and generates AI study guides instantly. Screenshot a slide, a ChatGPT explanation, a textbook page, or a whiteboard, LectureVault reads it and files it into the right folder instantly.

---

## The problem

You screenshot lecture slides, type out notes, grab explanations from ChatGPT, photograph textbook pages and all of it ends up in one chaotic camera roll. Finding anything later is a nightmare.

LectureVault fixes that. Every photo goes into the right subject folder automatically, without you having to think about it.

---

## What it works best on

Digital screenshots are where LectureVault shines:

- Lecture slides and presentation screenshots  
- ChatGPT / AI tool explanations  
- Textbook and PDF page photos  
- Typed notes and study guides  
- Website and article screenshots  

Printed and neat handwritten notes are also well supported. The OCR pipeline handles clean text reliably.

Heavily cursive or very messy handwriting is best effort. Classification still works when enough keywords are readable, but digital content gives the most consistent results.

---

## How it works

### 1. OCR, Google ML Kit (on-device)

Text recognition runs entirely on your device. No internet required for this step.

It extracts every single word from your images using background OCR. An enhancer layer then:
- fixes common OCR mistakes  
- removes noise words  
- extracts meaningful keywords  
- detects academic patterns using regex  

---

### 2. Classification, Gemini Flash

All OCR results from a batch of photos are sent to Gemini in a single request.

Gemini returns:
- subject label  
- confidence score  

The prompt is structured so Gemini reasons through the content before assigning a label, improving accuracy on tricky or mixed content.

---

### 3. Full-Text Search (Local)

Every word from your screenshots is saved into a local search index under a dedicated `ocrFull` field.

- Supports multi-word queries  
- Matches words anywhere in the image  
- Returns results instantly  

Deleting a photo also removes it from the index to keep everything clean and lightweight.

---

### 4. AI Study Material Generation

You can select:
- individual images  
- or full subject folders  

The app sends extracted OCR text to Gemini and generates:
- summaries  
- flashcards  

No prompt writing needed. It just works.

---

### 5. Storage, fully local

- Photos are stored in subject-based folders  
- Folder location is user-defined  
- Preferences stored using SharedPreferences  

Nothing leaves your device except OCR text sent to Gemini for classification.

---

## Features that student need (like me)

You can:
- browse notes  
- zoom into images  
- search instantly  
- share directly  

All inside the app.

Includes:
- animated splash screen  
- search tab in bottom navbar  
- improved UI with vivid buttons  

Think of it as your own notes app that organizes everything for you automatically.

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

### Prerequisites

- Flutter SDK  
- Android physical device (API 21+)  
- Gemini API key (free at https://ai.google.dev)

---

### Setup

```bash
git clone https://github.com/Aneezakiran07/LectureVault
cd lecturevault
flutter pub get
````

Create a `.env` file in the project root:

```
GEMINI_API_KEY=your_key_here
```

Add `.env` to `pubspec.yaml`:

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
│   ├── splash_screen.dart
│   ├── onboarding/folder_setup_screen.dart
│   ├── home/home_screen.dart
│   ├── upload/upload_screen.dart
│   ├── folder_view/folder_view_screen.dart
│   ├── search/search_screen.dart
│   └── settings/settings_screen.dart
└── services/
    ├── storage_service.dart
    ├── permission_service.dart
    ├── search_service.dart
    ├── ocr_service.dart
    ├── ocr_enhancer.dart
    ├── ocr_result.dart
    ├── classifier_service.dart
    └── gemini_classifier.dart
```

---

## Under the hood

LectureVault handles async operations and edge cases carefully:

- Memory Management
  Background processes stop instantly when leaving screens using mount guards

- Batch Upload Safety
  Uses hash-based filenames to prevent overwrite during fast processing

- Smart Error Handling
  Duplicate and constraint errors are treated as success to avoid crashes

- Index Sanitization
  Filters out UI error messages so search data stays clean

---

## Rate limits

Gemini free tier allows 500 requests per day.

LectureVault batches uploads:

* 1 session = 1 request
* 20 photos = still 1 request

That is up to ~10,000 photos per day.

---

## Limitations

* Android only
* Low-text images may be marked Unclassified
* Internet required for Gemini classification
* OCR works offline

---

## Development approach

Built incrementally:

UI → Storage → File handling → Folder view → Settings → OCR → Classification → Search → AI study generation → Async + memory fixes

Each stage was developed and improved step by step.

```
```
