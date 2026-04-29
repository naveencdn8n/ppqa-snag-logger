# PPQA Snag Logger — Pending Play Store Release Notes

> This file tracks every change made during the testing phase.
> When the testing phase is complete, use this to write the
> "What's New" section in Play Console and bump the final version.

---

## Pending version: TBD (target after testing phase)
**Last Play Store release:** 1.0.7+8 (26 Apr 2026)

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

## 📋 Changes Being Tracked (Testing Phase — In Progress)

| # | Change | Type | Status |
|---|--------|------|--------|
| 1 | Photo markup toolbar (Pen/Circle/Rect/Arrow/Line/Text/Highlight) | Feature | ✅ Done |
| 2 | Offline mode hang fix — snag saves instantly, photos queue for later | Bug Fix | ✅ Done & verified by user |
| 3 | Form auto-scrolls to top after snag submitted | Bug Fix | ✅ Done |
| 4 | Evidence upload errors now shown instead of silently swallowed | Bug Fix | ✅ Done |
| 5 | Sheets export UNAUTHENTICATED error fix | Bug Fix | ✅ Done |
| — | *more items will be added as testing feedback comes in* | — | — |

---

## Play Store "What's New" Draft (to be finalised)

```
What's New in this update:

• Markup Tools — Annotate evidence photos with pens, circles, arrows,
  text, and a highlight tool before saving. Circle a crack, draw an
  arrow to the defect, or highlight the problem area.

• Works Offline — Snags are now saved instantly even with no internet.
  Photos queue automatically and upload when you're back online.
  No more freezing or errors when submitting in low-connectivity areas.

• Form resets automatically after each snag is logged, scrolling back
  to the top so you're ready for the next entry immediately.

• Improved error messages when photos fail to upload.

• Sheets export reliability improvements.

[Add more items here as testing feedback is implemented]
```

---

*Updated: 2026-04-29 | Maintained by: development team*
