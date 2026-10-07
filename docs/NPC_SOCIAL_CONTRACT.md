# Opening social ownership contract — bounded candidate

Existing generic IDs: `pilot_traveler` / P01; `pilot_bridge_keeper` / P02; `pilot_pilgrim` / P03. No canon actor is added or killed. Motion, routes, resident count and explicit downed Kill/Spare are the reviewed P2 implementation.

`NpcWorldState` is the sole authority for resident life, HP, mode, authored room, trust/fear/debt from attacks and mercy, DOWNED episode and terminal tombstone. Its new read-only `life_id(id)` returns `<npc_id>:opening:1` for the existing single authored life. A dead pilot never gets another generation. A future birth/respawn design must explicitly version this contract; consumers must not mint life IDs.

The owner supplies a read fence with actor/life/path and semantic live/durable fingerprints. Fingerprints include HP, room, DOWNED episode, trust/fear/debt and death, and exclude position, route phase and NPC clock. Help accepts living walk/rest/work/talk, refuses flee/downed/recovering/dead or fear >= 12, and validates the primary sidecar without restoring old alive backups. It has no timer, save or new life owner.

`SanctuaryProfile` owns banked `material_stash` and optional `npc_social_progress`:

```json
{"schema_version":1,"receipts":{"pilot_traveler":{"life_id":"pilot_traveler:opening:1","event_id":"pilot_traveler:opening:1:help:linen:1"}}}
```

Exactly one receipt per actor/life. Cost is 2 existing `linen_fiber`, enough for the existing 1-bandage recipe. Debit and receipt are written in ONE canonical profile image under the existing EconomySession lock. This is not a two-file transaction: no sidecar mutation happens for help. Ordinary IO failure restores both RAM values. The NPC read fence is rechecked before the profile replaces its primary. Repeat clicks, encounters and cold loads do not debit or gain relation again.

`NpcSocialProgress.relationship()` is a detached projection: traveler +1 trust/+1 debt; bridge keeper +0 trust/+2 debt; pilgrim +1 trust/+1 debt. Fear stays the sidecar value. This delta is never copied back into the NPC record or cultivation ledger. An attack remains the directly harmed actor's experience (current pilot trust < 0); a spare remains its existing debt > 0. Environment/unknown attacks never create player blame. No moral broadcasts or remote witnesses are invented.

Presentation consumers read the receipt, owner life state and projection. A later encounter recognizes an earlier act; help reveals an existing dry walking route and changes that resident's work caption. Fear >= 12 visibly withholds further help and route advice. Keeping material is valid and carries no automatic relation penalty. There are no companion/friendship promises, romance, new locations or sect simulation. The actor art remains temporary vector art.

## Integration boundary for cultivation and sect workers

Do not create another clock, wallet, resource owner, profile file or life registry. Cultivation's profile writer remains the writer behind `SanctuaryProfile.save`; social contributes extension validation/load/export and a proposal with resource cost, receipt and the owner's life fence. The current standalone baseline implementation adds that hook to the existing v1 profile; the integrator must place it into the common `_save_with_context(fence,guard)` writer hook if the cultivation v2 profile lands first. Keep `npc_social_progress` in the common codec and retained extensions; never overwrite its receipt while saving cultivation or a courier event.

The cultivation candidate's `opening_npc_life_adapter.gd` observed during audit currently advertises source_schema 1; reviewed motion uses NPC schema 2 and accepts schema 1 migrations. Consume `NpcWorldState.valid()` and the life owner API rather than constructing a second generation/registry. Social does not enroll or independently advance cultivation. Its three social IDs differ from cultivation's `pilot_gatherer`, so receipt consumers must check actor_id and life_id explicitly.

`NpcPopulation.register_dialogue_extension(namespace, provider, handler)` composes up to two existing owner namespaces (`courier`, `cultivation`) after social lines/choices, before Leave. Provider receives `(npc_id, detached_record)` and returns `{lines:Array,choices:Array}` with only its own `<namespace>_*` IDs. Handler receives `(npc_id,choice_id)` and returns `{handled:bool,message:String}`; a handled response reopens the same locked living dialogue. Owners keep their own transaction/receipt logic. No extension is offered or dispatched while DOWNED. Namespaces register once; they cannot replace `pilot_help`, Kill/Spare or another owner.

For task-3, bind a courier provider that only accepts `pilot_pilgrim`, calls `courier.arm(&"pilgrim")`, then returns `courier.lines(&"pilgrim")` and `courier.choices(&"pilgrim")`. Bind a handler that checks the same actor/context and delegates to `courier.apply_action(choice)`. Replace task-3's inline population choice-dispatch branch with this registration; do not keep both handlers. Its `opening_courier_supply_v1` receipt, `prepare/help` outcome and proposed dust cost remain separate from social cloth help. Do not call social help or add trust/debt when handling that receipt. Keep task-3's existing stationary shrine fallback, quarantined-population prompt and healer content; those files are outside this payload.

The common transaction owner was observed adding `commit_extension_event(scope_id,event_id,materials_cost,souls_cost,next_state,expected_revision,fence,guard)` for profile v2. This is an integration API in progress, not a reviewed dependency in this candidate. If the owner selects its `event_extensions.namespaces.npc_social.state` as canonical storage, expose that state through the existing social getter, migrate/remove the old root extension exactly once, and route the help proposal through this API. Do not keep a mirrored root receipt or add a second profile commit. The root v1 implementation here is a tested standalone baseline, and its full-file payload must not overwrite the worker's common profile. The integrator/transaction owner must choose the location and recovery fence together before activation.

Attack/mercy events already have durable owner facts; execution event remains the DOWNED `id:episode` token. Help event is the deterministic namespaced ID above. No second event sequence or gameplay clock is introduced for social. A cultivation/sect consumer may refer to this event ID as an external cause but must not issue it again or apply its relation delta twice.
