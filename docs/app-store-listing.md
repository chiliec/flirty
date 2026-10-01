# App Store listing

Copy and answers for App Store Connect. Character limits are Apple's.

## Name (30)

Flirty: Reply Assistant

## Subtitle (30)

Thoughtful replies, on-device

## Promotional text (170)

Paste her message, pick a tone, get a reply that sounds like you. Generated on your iPhone with Apple Intelligence. No account, no tracking, nothing leaves your phone.

## Description (4000)

Flirty helps you answer the messages you keep rereading. Paste what she sent or drop in a chat screenshot, add a line of real context if you want, pick a tone, and tap Generate. You get a short, natural reply you can copy or regenerate until it fits.

SCREENSHOT IN, REPLY OUT
Pick a screenshot of the chat and Flirty reads the text on your iPhone. No retyping, and the image never leaves your phone.

KEEP IT REAL
Flirty writes from the context you give it: your notes about her and what you actually have going on. It never invents facts about your life. Replies are two to four sentences, in texting style, not essays.

TONES THAT MATCH THE MOMENT
Sweet, flirty, funny, and more. Switch tones and regenerate to try a different angle on the same message.

ONE PROFILE PER PERSON
Keep notes about each person you talk to, and Flirty remembers the conversation: recent messages stay verbatim, older ones are folded into a running summary so replies stay consistent over time.

PRIVATE BY DESIGN
On iPhones with Apple Intelligence, every reply is generated on the device by Apple's on-device model. Your messages, notes, and replies never leave your phone. There is no account, no analytics, and no telemetry.

CLOUD OPTION FOR OLDER IPHONES
On iPhones that do not support Apple Intelligence, Flirty can use a cloud model instead. It is off by default and asks for your consent first. When enabled, only the text needed to write the reply is sent over HTTPS, and it is not stored.

REQUIREMENTS
iOS 26 or later. On-device replies need Apple Intelligence (iPhone 15 Pro and later). Older iPhones on iOS 26 can use the cloud option.

## Keywords (100)

dating,reply,texting,flirt,message,chat,tone,wingman,apple intelligence,conversation,rizz,answer

## What's new (v1.0)

First release.

## Category

Primary: Lifestyle. Secondary: Social Networking.

## URLs

- Support: https://github.com/chiliec/flirty
- Privacy policy: https://github.com/chiliec/flirty/blob/main/PRIVACY.md (repo is public)
- Marketing: none

The same text is in the app behind the shield icon on the list screen (`PrivacyView`).

## Age rating

Questionnaire: everything None/No except Mature or Suggestive Themes = Infrequent. The app writes romantic chat replies from user input. Apple's on-device guardrails and the cloud model's own policy block explicit content.

Apple calculates 9+ from that; overridden to 13+ (shown as 12+ on OSes before 26). Filled in 2026-10-01.

## App privacy (nutrition labels)

Does the app collect data: **Yes**, one type.

| Data type | Collected | Linked to user | Used for tracking | Purpose |
|---|---|---|---|---|
| User Content > Other User Content | Yes, only in cloud mode | No | No | App Functionality |

Notes for the form:
- Her message (typed, pasted, or OCR'd from a screenshot on device), the user's notes and context, and the stored conversation summary are sent to the Flirty gateway only when cloud mode is on. Images never leave the device; the photo picker is the privacy-preserving one, so there is no photo-library permission. Cloud mode only exists on devices without Apple Intelligence. Requests are processed transiently and not stored.
- No identifiers, contact info, usage data, or diagnostics are collected. No third-party SDKs.
- Matches `Flirty/PrivacyInfo.xcprivacy`.

## Export compliance

Uses only standard HTTPS. `ITSAppUsesNonExemptEncryption` is NO in Info.plist, so App Store Connect should not prompt.

## App Review notes

No login. No demo account needed.

On-device mode requires Apple Intelligence. On a review device without it, the app shows a consent screen on launch; tap Allow and generation works over the network. To turn cloud mode off again, tap the cloud icon on the main screen. The review device must be on iOS 26.

To test: tap +, enter a name and an optional note, save, open the profile, paste any message into "Her message", pick a tone, tap Generate. Copy and Regenerate appear under the reply.

## Release steps

```sh
xcodegen generate
xcodebuild archive -project Flirty.xcodeproj -scheme Flirty -destination 'generic/platform=iOS' \
  -archivePath build/Flirty.xcarchive
xcodebuild -exportArchive -archivePath build/Flirty.xcarchive -exportOptionsPlist Config/ExportOptions.plist \
  -exportPath build/export
```

`Config/Secrets.xcconfig` must be present when archiving, or the build ships without a cloud tier and ineligible iPhones see "Device Not Supported". Bump `CURRENT_PROJECT_VERSION` in project.yml before every upload.

Upload with the account signed into Xcode (no API key or issuer ID needed): same export options plus `destination: upload`.

```sh
sed 's#<key>method</key>#<key>destination</key><string>upload</string><key>method</key>#' \
  Config/ExportOptions.plist > build/UploadOptions.plist
xcodebuild -exportArchive -archivePath build/Flirty.xcarchive -exportOptionsPlist build/UploadOptions.plist \
  -exportPath build/upload -allowProvisioningUpdates
```

It fails with `missingApp(bundleId: "com.flirty.app")` until the app record exists: App Store Connect → Apps → + → New App (iOS, bundle ID com.flirty.app, SKU flirty-ios). Created 2026-10-01 as "Flirty: Reply Assistant" because "Flirty" was taken; build 1.0 (1) uploaded the same day.

Done in App Store Connect on 2026-10-01: all listing text and screenshots, subtitle, categories, age rating, content rights (no third-party content), privacy policy URL and published nutrition label, price free in all 175 regions, build 1.0 (1) attached to version 1.0, automatic release. Left for the account owner: App Review contact info (name, phone, email), the review notes above, and "Add for Review".

## Screenshots

Captured 6.9-inch shots live in `docs/screenshots/6.9/` (1320x2868, iPhone 17 Pro Max). Regenerate with:

```sh
SIM=<udid of "iPhone 17 Pro Max (screenshots)">
xcrun simctl boot $SIM
xcrun simctl status_bar $SIM override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
TEST_RUNNER_SCREENSHOT_DIR=/tmp/fl-shots xcodebuild test -project Flirty.xcodeproj -scheme Flirty \
  -destination "id=$SIM" -only-testing:FlirtyUITests/ScreenshotTests CODE_SIGNING_ALLOWED=NO
cp /tmp/fl-shots/*.png docs/screenshots/6.9/
```

`ScreenshotTests` skips itself unless `SCREENSHOT_DIR` is set, so CI never runs it. The reply is canned via `FLIRTY_STUB_RESPONSE`.

Upload order:

1. `03-chat-reply` — generated flirty reply with Copy/Regenerate.
2. `02-chat-input` — her message, tone picker, context.
3. `01-list` — profile list.
4. `04-privacy` — privacy screen.
