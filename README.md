# 🏥 Digital Medical ID Application

> **"Medical ID: Speaks for you when you can't."**

## 📖 Overview
**Digital Medical ID** is a life-saving application developed with **Flutter**. It is designed to assist users in emergency situations by functioning as both a **Digital Medical Tag** accessible from the lock screen and an **Automated Safety Tracking System** (Dead Man's Switch) for the elderly or those living alone.

If the user becomes unresponsive, the system automatically triggers an SOS alert to emergency contacts with real-time GPS coordinates.

## ✨ Key Features

### 🛡️ 1. Medical ID Mode (Passive Protection)
Displays critical health information on the lock screen.
- **Unremovable Notification:** Utilizes Foreground Service technology to create a "Sticky Notification" that cannot be cleared, ensuring information is always visible.
- **Vital Info:** Shows Name, Blood Type, Allergies, and Emergency Contacts immediately.
- **Privacy First:** All data is stored locally via SQLite; no data is uploaded to the cloud.

### ⏱️ 2. Tracking Mode (Active Protection)
Automated "Dead Man's Switch" system.
- **Check-in System:** Users must verify their safety within a set interval (e.g., every 2 hours).
- **Automated SOS:** If the timer expires without a check-in, the system triggers:
  - 📍 **GPS Tracking:** Retrieves current coordinates.
  - 📧 **Emergency Email:** Sends an alert email with a Google Maps link.
  - 📞 **Auto Call:** Automatically dials the emergency contact number (background execution supported).

### 💊 3. Drug & Health Info
- **Smart Search:** Search for drug allergies using the FDA API (supports both Generic & Brand names).
- **Profile Management:** Record medical conditions and history.

---

## 🛠️ Tech Stack

### Core Framework
- **Flutter & Dart** (Cross-platform Development)

### Key Libraries & Architecture
- **State Management:** Native `setState`
- **Background Processing:**
  - `flutter_foreground_task`: Manages background services and sticky notifications.
  - `android_alarm_manager_plus`: Ensures precise timing even in Doze mode.
- **Notifications:** `flutter_local_notifications`
- **Location Services:** `geolocator` (High accuracy GPS)
- **Database:** `sqflite` (Offline local storage)
- **Communication:** `url_launcher`, `android_intent_plus`, `mailer`

---

⚠️ Important Note

This application relies on Background Execution. On Android 12+ and specific manufacturers (Vivo, Xiaomi), you may need to manually enable:

    "Display over other apps" permission.

    "Autostart" permission to ensure the SOS system functions correctly.
