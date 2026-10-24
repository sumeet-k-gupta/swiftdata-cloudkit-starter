# CloudKit pre-release checklist

Do this before every TestFlight / App Store build that touches the data model. None of it can be checked by unit tests.

## One-time setup
- [ ] Bundle id and iCloud container in `project.yml` are yours (not the `com.example` placeholders), and match `StoreFactory.defaultCloudKitContainerID`.
- [ ] Capabilities present: iCloud (CloudKit) with your container, Push Notifications, Background Modes: Remote notifications.
- [ ] Models obey the rules: defaults or optionals, optional relationships with inverses, no unique attributes (`make test` runs the schema lint).

## Every model change
1. [ ] **Dev build on a real device** signed into iCloud. Launch it, create/edit at least one record of every type. This creates/updates the record types in the CloudKit **Development** schema.
2. [ ] Open the CloudKit Console, select the container, Development environment. Confirm all record types and fields (`CD_` prefixed) are there.
3. [ ] **Deploy Schema Changes to Production.** Review the diff in the console before confirming.
4. [ ] Only then archive for TestFlight/App Store. Skipping step 3 makes sync fail silently in production.

## Test on devices
- [ ] **Two-device test:** two devices, same iCloud account. Create, edit, toggle, delete on each. Changes arrive on the other (can take a minute; background pushes are not instant).
- [ ] **Duplicate test:** create the same-keyed record on both devices while offline, go online, confirm both converge on the same single survivor and no child items are lost.
- [ ] **Reinstall test:** delete the app, reinstall, confirm data restores from iCloud.
- [ ] **Signed-out test:** sign out of iCloud (or disable it for the app); the app must still launch and work with local storage.
- [ ] **Upgrade test:** install the previous production build, add data, update to the new build, confirm no data loss.

## Change rules
- Only **add** properties, and give each a default (or make it optional).
- **Never rename or delete** a field/record type that has shipped; production schemas are additive-only.
- Never use `@Attribute(.unique)`; merge duplicates yourself, deterministically and idempotently.
- Preview/test/screenshot containers: `cloudKitDatabase: .none`, always.
- After any change, repeat the "Every model change" steps.
