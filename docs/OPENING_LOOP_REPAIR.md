# Opening loop repair — isolated implementation

The current opening lost access to the bounty combo after an equipped death and retried failed reward/return saves every frame. The isolated patch retains the learned moveset, holds failed permanent rewards until an explicit retry, and records six opening milestones from real events. No original project writes, new floors/enemies/realms, player motor edits, or story/ending changes were made.

`HubPreparation.starter_inventory(profile)` equips one fresh Common bounty moveset sword when the bounty was permanently claimed. It never restores the dead sword UID, quality, enhancement, affixes or sockets. Existing safe wardrobes are preserved. For older saves already affected by the bug, `EconomySession.reclaim_bounty_moveset` teaches an owned regular starter sword using its current UID; it neither reopens the bounty nor grants another item. The NPC service exposes that recovery only when an owned usable starter exists and no bounty sword is present.

`GameFlow.return_save_state()` and `DungeonRun.pending_reward_state()` expose detached recovery state. Failed proof, Soul/blueprint pickup, exploration milestone and victory bank saves have no automatic frame retries. A nonmodal `RunSaveRecovery` button explicitly retries the pending work. Return/restart callbacks cannot clear a pending run, and the transaction guards hold through callbacks. Death recovery commits an already attempted permanent reward while discarding ordinary carried gear/coins according to the existing ownership rule.

Review follow-up: a failed Soul/blueprint pickup now reparents immediately into the run-owned hidden `PendingPermanentRewards` node, outside both the room and `GearSession.loot`. Ordinary room cleanup still deletes uncollected drops; it cannot delete an attempted permanent transaction. Recovery state/retry methods read this persistent owner, and successful collection releases the same pickup. Room advance remains available; no guard or stage-assignment change is needed.

`opening_progress` is an optional bounded v1 profile extension, independent of geography and future cultivation. Missing fields keep legacy save layout; malformed extension data is quarantined independently; a future extension cannot be overwritten. `profile.opening_objectives()` returns a detached snapshot (`completed`, `next_id`, `complete`) and `profile.changed` announces committed changes. Milestones observe play and do not lock movement, require an NPC kill, or alter canon.

| Milestone | Authoritative event |
| --- | --- |
| `explored` | Successful exterior door commit or entering the existing campaign exploration stage |
| `golem_defeated` | Committed deduplicated Golem proof receipt |
| `reward_collected` | Committed collection of an actual Golem Soul mote |
| `returned_to_hub` | Committed victory-run return, independent of random Soul collection; see private progression repair |
| `thanh_vy_met` | Opening Thanh Vy's actual service dialogue |
| `first_upgrade` | Successful existing permanent-upgrade purchase |

The ordinary Golem drop table still permits an empty drop. The integration test uses a private deterministic drop-table copy, never changes the product chance, and proves the existing 25-Soul mote pays for the 20-Soul first HP upgrade (+10 maximum HP), leaving five Souls. The test advances real scenes/events but does not certify combat feel or end-to-end keyboard/GPU play.

Focused final tests after the room-ownership repair: opening loop 312, World Economy 81, Save Transaction 58 and Exterior Route 149 checks at both 60/120 Hz: **1,200 checks, 0 failures, clean final logs, native engine exit 0**. Final isolated import is also clean. The new test first reproduced 48 failures at 60 Hz before the ownership repair. At each of the four native Windows writer/backup-copy/backup-rename/main-rename boundaries, both Soul and blueprint tests now fail real collection, unlock the fixture's existing door, call real `advance_room`, verify the same pickup survives outside disposable loot, retry via the next room's actual recovery button, reload, then check repeated return callbacks bank the reward and seven carried coins once. Recursive/repeated callbacks, death/reload, first upgrade, claim and relearn remain covered. Profile file replacement retains the existing backup/two-rename protocol; this is validated logical transaction rollback and idempotency, not a new power-loss atomicity guarantee.

Pending escrow exists in the current session. An explicit quit or process loss before a successful save can lose uncommitted work. No GPU or full strict suite was run, as requested. The minimal retry notice still needs the UI owner's visual review. A same-frame synthetic sequence of multiple exterior transitions followed immediately by launch exposed the existing detached `SlicePresentation._scan` callback; the final test waits actual frames between those player actions. Presentation lifecycle was not changed by this patch.

The separate QA gate worker owns its default-off capability. Its patch applies cleanly to this candidate when excluding `scripts/hub/game_flow.gd`; that file requires manually preserving its export and three forwarding assignments around this patch's return changes. This worker did not apply the QA patch or copy the cultivation worker's future transaction implementation. Combined integration/validation belongs to the main integrator.
