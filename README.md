<div align="center"><img width="200" height="200" alt="Image" src="https://github.com/user-attachments/assets/27d80d83-aaed-4d18-abdf-4ed38981e0e0" /></div>

# GitLab MR Monitor (macOS Menu Bar)

A lightweight and native macOS menu bar application to monitor your GitLab Merge Requests in real-time. Built with SwiftUI.


<img width="519" height="649" alt="Image" src="https://github.com/user-attachments/assets/3e3f4eb5-e91a-45f9-bdba-4c732ae53672" />


## ✨ Features

- **Dual View**: 
  - **My MRs**: Shows all Merge Requests you created or are assigned to.
  - **To Review**: Lists MRs where you are designated as a reviewer.
- **Native Push Notifications**: Get alerted instantly when a new Merge Request is assigned to you for review.
- **Real-time Counters**: Dynamic counts directly in the tab headers.
- **Auto-Refresh**: Customizable background sync (15s to 5min).
- **Native Look & Feel**:
  - Displays author avatars.
  - Supports GitLab labels (Feature, Bug, etc.) with matching colors.
  - Relative timestamps (e.g., "2 hours ago").
  - "Draft" badges for in-progress work.
- **Dark Mode Support**: Adapts perfectly to your system theme.
- **Localization**: Available in English and French.

## 🚀 Setup

### 1. Requirements
- macOS 13.0 or later.
- Xcode 15.0+ (to build from source).

### 2. GitLab API Token
To use this app, you need a **Personal Access Token** from GitLab:
1. Go to your GitLab **User Settings > Access Tokens**.
2. Create a new token with the `read_api` scope.
3. Copy the token.
