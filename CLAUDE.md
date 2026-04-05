## 1. Core Vision\
A minimalist, ultra-modern macOS ToDo app ("Klen") focused on speed and "Quick-Capture" via global shortcuts.\
\
## 2. Requirements (The 19 Pillars)\
1. **UI:** Modern, simple, Apple-style (Light/Dark).\
2. **Dashboard:** View open, overdue, and future tasks.\
3. **Groups:** Support for task categorization.\
4. **Attributes:** Optional priority and due dates.\
5. **Sorting:** Dashboard groups by date; overdue items are highlighted.\
6. **Quick-Add (n + space):** Floating NSPanel for instant capture with "Today/Tomorrow" buttons and group assignment.\
7. **Persistence:** SwiftData. No data loss. Multi-device compatible build.\
8. **Branding:** Use colors/assets from `icon_reference.html`.\
9. **Performance:** Zero-lag, native Swift.\
10. **Localization:** German and English (Localizable.xcstrings).\
11. **Trash:** Display completed/deleted tasks with permanent delete option.\
12. **Details:** Optional long descriptions for tasks.\
13. **Status Bar:** Icon with status dot (Green = Running, Red = Error).\
14. **Installer:** Modern macOS-standard DMG/Installation UI.\
15. **Focus:** Quick-Add must not steal focus or force main app to foreground.\
16. **Search:** Search across active and completed tasks.\
17. **Shortcut:** Customizable (Default: n + space).\
18. **Permissions:** Minimal Accessibility/Input permissions (one-time).\
19. **Theming:** Full Dark/Light mode support.\
\
## 3. Technical Stack & Rules\
- Framework: SwiftUI / SwiftData / KeyboardShortcuts package.\
- Architecture: MVVM.\
- **Token Efficiency:** No yapping. No boilerplate. Diffs only. Use concise Swift syntax. \
- **Context:** Always check this file before proposing architectural changes.
