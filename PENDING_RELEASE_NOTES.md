# PPQA Snag Logger — Release Notes

> This file tracks every change made during the testing phase.
> Use the "What's New" section below when submitting to Play Console.

---

## ✅ Released version: 1.0.8+9 (04 May 2026)
**Previous Play Store release:** 1.0.7+8 (26 Apr 2026)

---

## 🆕 New Features

### Photo Markup Tools
Inspectors can now annotate evidence photos before saving:
- **7 drawing tools:** Pen (free draw), Circle, Rectangle, Arrow, Line, Text, Highlight
- **Highlight tool** paints a semi-transparent yellow fill over defect areas — great for calling out exactly what needs attention
- **7-colour palette:** Red, Orange, Yellow, Green, Blue, White, Black
- **3 stroke widths:** Thin / Medium / Thick
- **Undo** button to remove the last stroke
- **Clear All** (with confirmation) to start fresh
- Tap the ✏️ pencil icon on any evidence photo thumbnail to open the markup editor
- Only the annotated version is uploaded — original photo is unchanged on the device

---

## 🐛 Bug Fixes

### Change Status Permission Error (Fixed)
Inspectors were getting a "permission denied" error when trying to change
the status of their own snags (including when attaching close-out photos).

Root cause: the app was storing the inspector's display name in the snag
record instead of their unique Firebase user ID. Firestore's security rule
checks ownership by user ID, so the comparison always failed — even for
snags the inspector had logged themselves.

Fix: the app now always stores the Firebase user ID as the snag owner.
Firestore rules also accept the display name as a fallback so that snags
logged before this fix (with the name stored) remain editable by their
original inspector.

### Offline Mode — Snag Submission No Longer Hangs (Fixed)
Submitting a snag with mobile data off (or on a weak connection) previously
caused the app to freeze for several minutes before timing out. The fix
was a multi-layered approach:

- The app now saves the snag text data instantly (typically under 2 seconds)
  regardless of network state, by detecting offline status before attempting
  any cloud operation.
- Real internet detection: the app probes for actual internet access rather
  than just checking whether a WiFi or mobile network interface is present.
- Hard timeouts on every network call so nothing can stall the UI for more
  than a few seconds, even if the underlying Firebase SDK is in an unusual
  state.
- Photos are uploaded in the background with a 25-second timeout. If the
  upload cannot complete — or if there is no internet — the photos are
  queued locally and uploaded automatically when connectivity is restored.
- A clear orange message tells the user:
  *"Snag saved! X photos will upload when back online."*

Tested working with: airplane mode, mobile data off, WiFi without internet.

### Snag Form Does Not Reset After Submission (Fixed)
After successfully logging a snag, the form now automatically scrolls back
to the top and shows blank fields, making it clear the form is ready for
the next snag entry. Previously, the form stayed scrolled to the Submit
button area and users could not tell the fields had been cleared.

### Evidence Upload Errors Now Shown to User (Fixed)
If a photo fails to upload to storage (e.g. poor connection, permission
issue), the error is now surfaced as a clear message instead of being
silently ignored. The snag is not saved in a partial state.

### Google Sheets Export Authentication (Fixed)
Resolved an issue where the Sheets export could fail with an
"UNAUTHENTICATED" error even when the user was signed in. The app now
refreshes the auth token before calling the export function.

---

## ⚙️ Under the Hood

- Improved error reporting when cloud operations fail
- Firebase Auth token refresh before Sheets Cloud Function calls
- Android google-services.json updated

---

## 📋 Changes Included in This Release

| # | Change | Type | Status |
|---|--------|------|--------|
| 1 | Photo markup toolbar (Pen/Circle/Rect/Arrow/Line/Text/Highlight) | Feature | ✅ Done |
| 2 | Offline mode hang fix — snag saves instantly, photos queue for later | Bug Fix | ✅ Done & verified |
| 3 | Form auto-scrolls to top after snag submitted | Bug Fix | ✅ Done |
| 4 | Evidence upload errors now shown instead of silently swallowed | Bug Fix | ✅ Done |
| 5 | Sheets export UNAUTHENTICATED error fix | Bug Fix | ✅ Done |
| 6 | Change Status permission-denied fix — inspectors can now update their own snags | Bug Fix | ✅ Done |

---

## Play Store "What's New" (ready to paste into Play Console)

```
• Markup Tools — Annotate evidence photos with pens, circles, arrows,
  text, and a highlight tool before saving. Circle a crack, draw an
  arrow to the defect, or highlight the problem area.

• Works Offline — Snags are now saved instantly even with no internet.
  Photos queue automatically and upload when you're back online.
  No more freezing or errors when submitting in low-connectivity areas.

• Change status fix — inspectors can now update the status of their
  own snags and attach close-out photos without a permission error.

• Form resets automatically after each snag is logged, scrolling back
  to the top so you're ready for the next entry immediately.

• Improved error messages when photos fail to upload.

• Sheets export reliability improvements.
```

---

*Updated: 2026-05-04 | Version: 1.0.8+9*
