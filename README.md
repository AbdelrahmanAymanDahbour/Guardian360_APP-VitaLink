<div align="center">

# 🛡️ Guardian360 — Smart Rescue Application (VitaLink System)

**Cross-platform Flutter mobile application for smart emergency response, Safe Arrival trip tracking, and Smart Kroka minor traffic accident reporting.**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart_%3E%3D3.10.7-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Google Maps](https://img.shields.io/badge/Google_Maps-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white)
![ML Kit OCR](https://img.shields.io/badge/Google_ML_Kit_OCR-0F172A?style=for-the-badge)

*Showcased at the **National Technology Parade 2026** (Public Safety Track)*

</div>

---

## 📌 Overview

**Guardian360** (`v1.0.0+1`) is the mobile client of the **VitaLink System** emergency response ecosystem. Built with **Flutter** and backed by **Firebase**, it combines real-time location services, device sensors, background execution, bilingual Arabic/English support, on-device OCR, and strict Firestore security rules to support both emergency rescue workflows and day-to-day road safety.

---

## 🚀 Core Modules & Capabilities

### 1. Emergency Rescue & Incident Reporting
* **Accident & Alert Workflows:** Real-time incident reporting (`accidents` with immutable `statusHistory` tracking) and interactive `alerts` acknowledgment/cancellation workflows.
* **Sensors & Background Services:** Hardware sensor integration (`sensors_plus`), background execution (`flutter_background_service`), battery monitoring (`battery_plus`), and connectivity tracking (`connectivity_plus`).
* **Medical Profile & Contacts:** Dedicated user `medicalHistory` and `emergencyContacts` management with device contacts integration (`flutter_contacts`).
* **Voice & Notifications:** Text-to-speech (`flutter_tts`), speech-to-text (`speech_to_text`), local alerts (`flutter_local_notifications`), push notifications (`firebase_messaging`), and bilingual in-app notifications (AR/EN).

### 2. Safe Arrival Trip Monitoring
* **Full Lifecycle Tracking:** Structured trip state machine enforced at the database level (`draft`, `ready`, `tracking`, `paused`, `arrived`, `danger`, `cancelled`, `failed`).
* **Live Navigation & Safety Telemetry:** Real-time GPS tracking (`geolocator`), custom-styled Google Maps (`google_maps_flutter`, `geocoding`), ETA/distance tracking, arrival radius monitoring, safety scoring, and family contact notifications.

### 3. Smart Kroka (Minor Traffic Accident Reporting)
* **Draft-to-Submission Workflow:** Schema-validated lifecycle (`draft` → `submitted` / `discarded`) capturing damage zones/sides, fault estimates, GPS coordinates, and insurance signals.
* **On-Device OCR:** Vehicle license plate recognition powered by **Google ML Kit** (`google_mlkit_text_recognition`).
* **Evidence & Official PDF Export:** Media/file evidence capture (`image_picker`, `file_picker`) and client-side PDF report generation with barcodes and print support (`pdf`, `printing`, `barcode`).

---

## 🔐 Security & Data Integrity (`firestore.rules`)

Security is enforced directly at the database layer via a strict **Default Deny All** policy:
* **Role-Based Access Control (RBAC):** Multi-tier operational roles (`super_admin`, `admin`, `manager`, `dispatcher`) validated against active admin documents with client-side privilege-escalation protection.
* **Strict Schema & State Validation:** Server-side verification of allowed fields, coordinate bounds, plate formatting, immutable identities, and server timestamps (`request.time`) across `safe_arrival_trips` and `kroka_reports`.
* **Auditability:** Immutable `statusHistory`, `activity_logs`, and `systemLogs` collections preventing client-side modification or deletion.
* **Client Authentication:** Firebase Authentication, Google Sign-In, biometric authentication (`local_auth`), and OTP verification with SMS autofill (`pinput`).

---

## 🛠️ Tech Stack

| Layer | Technologies & Packages |
| :--- | :--- |
| **Framework & Language** | Flutter, Dart (`>=3.10.7 <4.0.0`), Material Design |
| **State & Localization** | `provider`, `easy_localization`, `intl`, `flutter_localizations` |
| **Backend & Cloud** | Firebase Auth, Cloud Firestore, Cloud Functions (`functions/`), Firebase Storage, FCM, Crashlytics, Performance Monitoring |
| **Maps & Sensors** | `google_maps_flutter`, `geolocator`, `geocoding`, `sensors_plus`, `flutter_background_service`, `battery_plus` |
| **AI / OCR & Reporting** | `google_mlkit_text_recognition`, `pdf`, `printing`, `barcode`, `image_picker`, `file_picker` |
| **Local Storage & Offline** | `hive`, `hive_flutter`, `shared_preferences`, `connectivity_plus` |
| **UI & Accessibility** | `google_fonts`, `flutter_animate`, `lottie`, `shimmer`, `flutter_tts`, `speech_to_text`, `pinput` |

---

## 📂 Repository Overview

```text
Guardian360_APP-VitaLink/
├── android/               # Android platform configuration
├── ios/                   # iOS platform configuration
├── lib/                   # Flutter application source code
├── assets/                # Images, localization files (langs/), and custom map styles
├── functions/             # Firebase Cloud Functions backend (Node.js)
├── test/                  # Automated Flutter tests
├── firestore.rules        # Production RBAC & schema-validated Firestore security rules
├── firebase.json          # Firebase project configuration
└── pubspec.yaml           # Flutter dependencies and asset declarations
