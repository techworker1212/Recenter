# App Store listing — Recenter

Draft for App Store Connect. Character limits are Apple's; counts are checked by
`python3 docs/check_listing.py`.

## App name (max 30)

Recenter: Screen Time Limits

## Subtitle (max 30)

Your words when time is up

## Promotional text (max 170, editable anytime without review)

Pick the apps that steal your time, set a limit, and write the reminder you need to hear. When time's up, Recenter shows your words, then pauses the app.

## Description (max 4000)

Recenter helps you stop losing hours to your phone and spend them on something better.

Pick the apps that pull you in, set a time limit for each one, and write the reminder you want to see when that time is up: in your words, for that app. When you reach the limit, Recenter shows your message, gives you five seconds, then pauses the app.

HOW IT WORKS
• Choose an app, like Instagram, TikTok or YouTube.
• Set how many minutes a day you want to spend there.
• Write your own reminder title and message, such as "That's enough TikTok. You said you'd go for a walk."
• When your time is up, your reminder appears. Five seconds later, the app is paused with your message on screen.
• Need it for something important? Unlock it for the time you chose for that app, and Recenter will check in again afterwards.

WHY YOUR OWN WORDS
Generic "time limit reached" screens are easy to tap past. A reminder you wrote to yourself, about why you wanted to stop, is much harder to ignore. Recenter puts your intention back in front of you right when you need it.

TODAY'S GOALS, RIGHT WHEN YOU NEED THEM
Each morning Recenter asks what you'll focus on today. Add a few goals, like "Read 20 pages" or "Go for a walk", right from that notification or in the app. Every reminder shows your goals, so stopping comes with something better to do, and you can tick them off straight from the reminder. Each day starts fresh.

A DIFFERENT LIMIT AND MESSAGE FOR EACH APP
Ten minutes of YouTube might be fine while thirty minutes of scrolling isn't. Give every app its own limit, reminder and unlock time, and turn rules on or off whenever you like. Everything resets at midnight.

PRIVATE BY DESIGN
• No account and no sign-up.
• No ads, no analytics, no tracking.
• Your limits, messages and usage never leave your iPhone.
Recenter uses Apple's Screen Time framework, so it works quietly in the background and only sees the apps you choose, never what you do inside them.

Recenter isn't about willpower or guilt. It's a quick pause that brings you back to what you actually wanted to do with your time.

Requires Screen Time permission. Privacy policy: https://techworker1212.github.io/Recenter/privacy.html

## Keywords (max 100, comma-separated, no spaces after commas)

focus,app blocker,doomscrolling,digital detox,social media,habit,mindful,distraction,reminder,phone

Notes: words already in the name and subtitle (recenter, screen, time, limits, words) are indexed
automatically, so they're left out here.

## What's new in this version (first release)

First release of Recenter. Set a time limit and your own reminder for any app, then let Recenter pause it when time's up.

## Other App Store Connect fields

| Field | Value |
| --- | --- |
| Primary category | Productivity |
| Secondary category | Health & Fitness |
| Age rating | 4+ (no objectionable content) |
| Price | Free |
| Privacy policy URL | https://techworker1212.github.io/Recenter/privacy.html |
| Support URL | https://techworker1212.github.io/Recenter/support.html |
| App Privacy answer | "No, we do not collect data from this app" → Data Not Collected |
| Copyright | © 2026 Techworker |

## App Review Information → Notes (paste into App Store Connect)

Recenter helps people limit their own use of apps they choose. It uses Apple's Screen Time
frameworks with individual authorization (AuthorizationCenter, .individual). It is not a
parental-control app and does not manage anyone else's device.

How Screen Time is used:
- FamilyActivitySelection / FamilyActivityPicker: the user picks the apps to limit.
- DeviceActivity: one monitor per app rule, with a daily time-limit event.
- ManagedSettings: when the limit is reached, the app is shielded until the user unlocks it.
- ShieldConfiguration / ShieldAction extensions: the shield shows the user's own message and
  offers "Close" or "Unlock for N min".
- A notification content extension shows today's goals as a checklist in the warning.

Privacy: no account, no server, no analytics or ads. Everything stays on the device in the
app's App Group storage. App names and icons are drawn by iOS from Screen Time tokens; the app
never learns them.

How to test (no login needed):
1. Open Recenter. Allow Screen Time access (requires the device passcode) and notifications.
2. Tap "Add app", tap "Pick an app" and choose any app, e.g. Safari.
3. Set "Time limit" to 1 minute, type any notification title and message, and tap Save.
4. Make sure "Monitoring" is on, then use the chosen app for a little over a minute.
5. A notification shows your message; about 5 seconds later the app is shielded with the same
   message. Tap "Unlock for 2 min" to reopen it, or "Close".
6. Optional: add goals under "Today's goals". They appear on the warning and the shield. Press
   and hold the warning notification to tick them off.
7. Optional: the morning reminder can be set to a minute from now under "Morning reminder".

Note: iOS can deliver the limit event up to a minute or so after the limit is reached.
