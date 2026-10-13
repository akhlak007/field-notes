# Demo guide

This walkthrough covers the core requirements using the release APK and public API.

## Before starting

1. Install `FieldNotes-v1.0.apk` on an Android phone.
2. Confirm that `https://field-notes-3.onrender.com/api/health` responds. A free Render instance can take up to a minute to wake.
3. Keep Android's network controls available so connectivity can be changed during the demo.

## Walkthrough

1. Register a new account and sign in.
2. Create a customer, then create a site under that customer.
3. Create a note with a title, description, status, date/time, location, and optional photo.
4. Search for the note by title, site, or customer, then filter it by status and site.
5. Edit the note and confirm the updated details are shown.
6. Open Settings, change the default note status, and confirm a new note starts with that status.
7. Disable the network. Create or edit a customer, site, and note; confirm the sync indicator shows pending/offline state.
8. Restore the network and wait for the sync indicator to show **Synced**.
9. Clear the app's local data, sign in again, and confirm the server data is restored.
10. Delete the demo records and confirm the deletions synchronize.

## Expected behavior

- The app remains usable without a connection after authentication.
- Permission denial shows guidance instead of crashing.
- Local changes remain queued after a failed sync and retry automatically.
- Each account can access only its own customers, sites, notes, and photos.
