# Project Name: SpaceSaver (Internal Code Name)

## 1. Product Vision
A friendly, native macOS cleaner that is simple enough for a casual user but powerful enough for a developer.
**Core Philosophy:** "Progressive Disclosure." The app should look simple (Dashboard view) but offer depth (Visualizer) when requested.

## 2. Target Audience
* **Primary:** General Mac users (Students, Creatives, Office Workers) who see "Disk Full" and panic.
* **Secondary:** Developers who want a quick way to nuke `node_modules` and Docker images without using CLI.

## 3. Core Features (The "Smart Dashboard")
Instead of showing a file tree immediately, the app opens to a **Dashboard** with 4-5 clear cards:
1.  **System Junk:** (Caches, Logs, Trash).
2.  **Large Files:** (Videos, Archives > 1GB).
3.  **Old Downloads:** (Files in ~/Downloads older than 3 months).
4.  **Developer Clean:** (Only appears if developer tools are detected).

## 4. The "Developer" Logic (Smart Detection)
The app should automatically detect if the user is a developer.
* *Logic:* If `/Applications/Xcode.app` or `/Applications/Docker.app` exists, OR if `node_modules` are found during scanning -> **Enable "Developer" Card.**
* *Benefit:* Regular users never see confusing "Docker" options; Developers get them automatically.

## 5. Monetization Strategy (Freemium)
* **Free:** Analyze space, visualize files, delete "Safe" System Junk.
* **Pro ($15 lifetime):** Unlock "Developer Clean," "App Uninstaller," and "Large File Bulk Delete."