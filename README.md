# Flirty

iOS 26 app that writes replies to the messages you keep rereading. Paste what she sent or pick a chat screenshot, add a line of context, choose a tone, tap Generate.

Replies are generated on the phone with Apple Intelligence. iPhones without it can opt into a cloud model after a consent screen. No account, no analytics. See [PRIVACY.md](PRIVACY.md).

## Build

Requires Xcode 26 and [xcodegen](https://github.com/yonaskolb/XcodeGen). The Xcode project is generated, not checked in.

```sh
xcodegen generate
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build
```

Cloud mode needs `Config/Secrets.xcconfig` (copy `Config/Secrets.example.xcconfig`). Without it the app is on-device only.

Commands, tests and release steps are in [CLAUDE.md](CLAUDE.md) and [docs/app-store-listing.md](docs/app-store-listing.md).
