# swiftdata-cloudkit-starter

A tiny SwiftUI "Checklists" app that shows a production-minded **SwiftData + CloudKit (private database)** setup: CloudKit-safe models, a store factory that falls back to local storage, deterministic duplicate merging, a debounced remote-change refresher, and a schema lint test.

The patterns come from lessons learned shipping an iOS app that syncs through iCloud. The app itself is deliberately trivial.

> **Honesty note:** the logic here is unit-tested. It has **not been run against live CloudKit by the author of this sample** (no iCloud account was available while building it). Two-device sync was never verified here. See [What is tested / what is NOT tested](#what-is-tested--what-is-not-tested).

## What's in it

| File | What it does |
|---|---|
| `Sources/Models/` | `Checklist` and `ChecklistItem`, written to CloudKit's rules |
| `Sources/Persistence/StoreFactory.swift` | Live CloudKit container, falls back to local-only with a logged reason, in-memory option. Reports which one you got as a `StoreMode` enum |
| `Sources/Persistence/Deduplicator.swift` | Generic, deterministic, idempotent duplicate merge |
| `Sources/Persistence/SyncRefresher.swift` | Observes `NSPersistentStoreRemoteChange` via a `Sendable` weak box, debounces, runs an idempotent refresh that saves only when something changed |
| `Sources/Views/` | List, detail (add / toggle / delete), empty state |
| `Tests/` | 21 Swift Testing tests, including a CloudKit schema lint |

Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`, iOS 18.0+, project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## 5-minute setup

1. `brew install xcodegen`
2. Replace the placeholders (search for `example`):
   - `project.yml`: `PRODUCT_BUNDLE_IDENTIFIER` (`com.example.localfirststarter`) and the iCloud container (`iCloud.com.example.localfirststarter`). Optionally add `DEVELOPMENT_TEAM`.
   - `Sources/Persistence/StoreFactory.swift`: `defaultCloudKitContainerID` (must equal the entitlement) and the logger subsystem.
3. `make generate` and open `Checklists.xcodeproj`.
4. In Xcode, set your Team under Signing & Capabilities. Xcode will create the iCloud container for your bundle id.
5. Run on a **real device signed into iCloud**. Then read [`docs/CLOUDKIT_CHECKLIST.md`](docs/CLOUDKIT_CHECKLIST.md) before shipping.

```
make generate   # xcodegen
make build      # simulator build, unsigned
make test       # unit tests on iPhone 18 Pro simulator (override: make test DEST='platform=iOS Simulator,name=...')
```

### Unsigned simulator builds: use `--local-only`

If the app has no iCloud entitlement (for example `CODE_SIGNING_ALLOWED=NO`), `ModelConfiguration(cloudKitDatabase: .private(...))` does **not** throw. We observed CoreData trapping on a background queue inside its CloudKit setup and killing the process, so a `catch` cannot save you. `StoreFactory.makeLive(cloudKitEnabled:)` therefore lets the caller opt out up front. The app passes `false` when launched with `--local-only` or when hosting unit tests. The `catch`-and-fall-back path still exists for errors that *are* thrown. In a signed build, don't pass the flag.

DEBUG builds also accept `--sample-data`: an in-memory store with sample lists, `cloudKitDatabase: .none`, so sample data can never reach anyone's iCloud.

## CloudKit gotchas

Written the way I'd tell a friend; each one cost me time.

- **Every stored property needs a default or must be optional.** CloudKit has no concept of a required field without a default. Give `var name: String = ""`, not `var name: String`.
- **Relationships are optional arrays with an explicit inverse.** `var items: [ChecklistItem]?` with `@Relationship(deleteRule: .cascade, inverse: ...)`. Not optional or no inverse = the container fails to load. `.deny` delete rules aren't supported either.
- **No `@Attribute(.unique)`.** CloudKit can't enforce uniqueness, so two devices can each create "the same" record and *both* survive sync. Expect duplicates and merge them deterministically (same winner on every device, or they fight). See `Deduplicator`.
- **Store enums as their raw `String`** (and expose a computed property). Don't store the enum type itself. (This sample has no enums; the rule is here because it bites later.)
- **Develop with a dev build on a real device.** That's what creates your record types in the CloudKit **Development** schema. The simulator can't do it for you.
- **Then "Deploy Schema Changes to Production" in the CloudKit Console** before any TestFlight/App Store build. If you skip it, sync silently fails in production. No error to the user.
- **Every later model change needs the same two steps** (dev build, then deploy to production).
- **Only add properties with defaults. Never rename or delete a synced field once it's in production.** Production schemas are additive-only.
- **A missing iCloud entitlement crashes rather than throws** (see above).
- **In-memory / preview / screenshot containers must use `cloudKitDatabase: .none`**, or sample data lands in the user's real iCloud.
- **Keep refresh idempotent.** If your remote-change handler saves every time, it triggers another remote change, which triggers another save. Only save when `hasChanges`.
- **Guard against objects a dedup just deleted.** After merging, a stale reference to a deleted duplicate can still be sitting in a view model or task; check `Deduplicator.isRemoved` before touching it.
- `NSPersistentStoreRemoteChange` isn't guaranteed to fire for every import, so also refresh on foreground and at launch (the app does).

## What is tested / what is NOT tested

**Tested** (`make test`, 21 tests, in-memory containers with `cloudKitDatabase: .none`):
- `Deduplicator`: no duplicates = no changes; duplicates merged to the same survivor regardless of input order (earliest `createdAt`, then smallest `uid`); children re-parented, not lost to the cascade; second run is a no-op.
- `StoreFactory`: CloudKit success mode; fallback mode and logged reason when the injected CloudKit builder throws; opt-out skips CloudKit entirely; throws only if the local store also fails.
- `SyncRefresher`: a burst of 10 notifications produces 1 refresh (using an injected `NotificationCenter` and notification name); `stop()` removes the observer; refresh saves only when it changed something.
- **Schema lint**: loads the SwiftData `Schema` and asserts no unique attributes/constraints, every relationship optional with an inverse, no `.deny` rule, every non-optional attribute has a `defaultValue`. The lint is itself tested against deliberately bad models. On Xcode 27.1 `Schema.Attribute.defaultValue` is populated for Swift initial values; a test fails if an SDK stops exposing it. Enum raw-String storage is not linted.

**NOT tested:**
- **Live CloudKit.** The `.private(containerID)` configuration was never exercised successfully by the author of this sample. It was never run with an iCloud account.
- **Two-device sync, conflict behavior, reinstall restore, schema deployment.** Do these yourself with the checklist.
- That a real `NSPersistentStoreRemoteChange` from CloudKit reaches `SyncRefresher` (tests post a synthetic notification).
- UI behavior (no UI tests; one manual simulator screenshot in sample-data mode).
- The debounce test is timing-based (80 ms window), so it could be flaky on a very loaded machine.

## Want more?

Want the full local-first iOS kit (StoreKit 2 subscription flow, notifications, widgets, localization)? Join the waitlist: https://tenacityhq.com/kit/?ref=github. This is an **unreleased product**; nothing is promised on features or dates.

## License

MIT, see [LICENSE](LICENSE).
