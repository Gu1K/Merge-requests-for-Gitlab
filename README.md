# GitLab MR Monitor (macOS Menu Bar)

A lightweight and native macOS menu bar application to monitor your GitLab Merge Requests in real-time. Built with SwiftUI.

![SwiftUI](https://img.shields.io/badge/SwiftUI-FF3300?style=for-the-badge&logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)

## ✨ Features

- **Dual View**: 
  - **My MRs**: Shows all Merge Requests you created or are assigned to.
  - **To Review**: Lists MRs where you are designated as a reviewer.
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
