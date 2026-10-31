# Phone messages from a custom contact (research, 2.5)

Question: can the in-game message system deliver messages from a custom contact? Answer: yes, by three routes. None needs new engine work. Status of each route is marked below. Nothing in this file has been shipped by the kit.

## How vanilla messages work (static: 2.5 RTTI and 2.31 scripts)

- Content is journal entries: `gameJournalContact` holds `gameJournalPhoneConversation`, which holds `gameJournalPhoneMessage` or `PhoneChoiceGroup` / `PhoneChoiceEntry`.
- Text is a LocalizationString (a LocKey into `onscreens.json`), resolved natively by `JournalPhoneMessage.GetText()`.
- A message is delivered when its entry state goes from Inactive to Active. Quest graphs do this with a Journal node. Scripts can do it with `JournalManager.ChangeEntryState(path, "gameJournalPhoneMessage", Active, JournalNotifyOption.Notify)` or with `ChangeEntryStateByHash`. Both exist on 2.5. So no quest phase is required.
- A picked reply can be detected with `RegisterScriptCallback(obj, 'OnJournalUpdate', gameJournalListenerType.State)`.
- Toast: `JournalNotificationQueue.OnJournalUpdate` builds a `PhoneMessageNotificationViewData` for the widget `notification_message` (class `MessengerNotification`). That widget shows `SMSText` when `SMSLocKey` is empty, so plain text works with the vanilla widget.
- UI data flow: the contact list comes from `MessengerUtils.GetSimpleContactDataArray`; a thread from `MessengerUtils.GetMessageDataArrayForContact`; the window is `MessengerDialogViewController`. A toast opens through `OpenPhoneMessageAction`, then `UsePhoneRequest`, then `PhoneSystem.OnUsePhone`.

## Route 1: a static journal thread (ArchiveXL)

Status: documented route; not built or tested in this kit.

- Author a `.journal` file. Its root entry must be `JournalRootFolderEntry`. ArchiveXL merges it at load.
- Put the message text in an onscreens JSON file, referenced with ArchiveXL's `localization: onscreens:`.
- An avatar or photo is optional: TweakXL `UIJournalIcons.*` and `PhoneAvatars.*` records, and an `.inkatlas`.
- The journal CR2W can be built from JSON with the WolvenKit CLI on Linux. Textures need the Windows CLI (`wolvenkit-cli-linux.md`).
- Needs ArchiveXL, RED4ext and redscript (the kit pins ArchiveXL 1.28.1, RED4ext 1.31.0 and redscript 0.5.32).
- The text is fixed at build time. Best for authored lines that do not change.
- Other mods use this route. Look at Nexus for examples.

## Route 2: a dynamic contact (Phone Extension framework)

Status: framework on Nexus (mod 24949, v0.9); its code was not run in this kit.

- Pure `.reds` (six files, no DLL). Needs redscript, RED4ext and Codeware.
- A mod subclasses `PhoneEventsListener` (methods `GetContactHash`, `GetContactData`, `ShowDialog`, `ActivateReply`) and calls `PushMessageCustom`, `PushReplyCustom` and `PhoneExtensionSystem.NotifyNewMessageCustom(hash, title, text)`.
- The text is any runtime string, so lines can come from a file or a socket.
- It cannot change vanilla contacts.
- Messages do not persist unless the listener saves them. The contact list is held by the script.
- Static check on 2.5: all 23 `@wrapMethod` and `@addMethod` targets exist in the RTTI, with matching parameter types. A mismatch fails at redscript compile, not silently. Untested in game.
- Licence: the Nexus download needs a login. The only public copy found had no licence. Do not copy its code. Write your own seams, or get the author's permission.
- Prior art to read about (not reviewed here): an Archipelago client that feeds the phone from an external process (repository `247Tossing/cyberpunk_archipelago`), Vehicle Insurance (Nexus 10039), and Night City Allies.

## Route 3: CET only (no framework)

Status: the API calls below are reachable from CET on 2.5. The toast and the faked thread are untested.

- Reachable from CET on 2.5: `ChangeEntryState*`, `GetEntryByString`, `RegisterScriptCallback`, `gameuiGenericNotificationGameController.AddNewNotificationData`, `NewObject` of `ContactData`, `JournalNotificationData`, `UsePhoneRequest`, `gameuiGenericNotificationData` and `OpenPhoneMessageAction`.
- `PhoneMessageNotificationViewData.new()` works. `NewObject` on that class fails.
- Plain-text toast (untested): capture a `JournalNotificationQueue` with `ObserveAfter` on `OnJournalUpdate`, build the view data with `SMSText`, and push the notification data with the widget `notification_message`. It gives a toast only, with no thread to reread.
- A faked thread by `Override` of the static `MessengerUtils` functions is untested. `ContactData` can be constructed.
- Combination (design, untested as a whole): Route 1 supplies the authored lines, and a CET trigger calls `ChangeEntryState` when the mod's own condition holds. That would give persistent threads without a quest graph.

## Probe plan (not yet run; each needs a live check)

- (a) `ObserveAfter` on `JournalNotificationQueue.OnJournalUpdate` to capture the queue, then push a plain-text toast.
- (b) Check that a toast left open with a nil action is harmless.
- (c) A static `Override` of `MessengerUtils.GetSimpleContactDataArray` that appends a fake `ContactData`.

These are runtime-only probes. None writes a save.

## Pitfalls met while researching

- Compact reflection JSON keys: `b` is the class name, `a` the parent, `e` the properties, `f` the functions. A function entry omits `b` when it equals `a`, so look it up with `f.get('b', f['a'])`. Some entries have no `b` at all; use `.get`.
- `JournalManager` is not in the dump; its native name is `gameJournalManager`.
- `jm:GetContacts(ctx)` returned 0 until `ctx.stateFilter` was replaced with a fresh `JournalRequestStateFilter.new()`. Assigning fields through `ctx.stateFilter.x` writes to a copy. After the fix it returned 80 contacts, as the array directly.
- Searching public code for `PhoneEventsListener` finds mods built on Phone Extension.
