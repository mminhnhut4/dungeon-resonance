# Asset pipeline gate: missing private fixtures

The default strict run reported `asset manifest parses` FAIL and JSON parse error at line 0 in tests/asset_pipeline_test.gd:14. The private checkout lacked docs/verification/asset_pipeline_manifest.json and the asset_pipeline_sources directory. FileAccess.get_file_as_string on that absent file provided empty JSON input. The main manifest was present, 7868 bytes, SHA256 31199a282174961c922f935f9179567f875645a6e673797f21116ee50776e1af; its first bytes were 7B-0D-0A, so this was not a UTF-8 BOM problem. The checkout/merge scripts exclude docs/verification; these particular files are read-only dependencies of the asset gate, rather than disposable output logs.

Fix confined to private fixture hydration: copied the unchanged main manifest and each of its referenced source images, original import metadata and archived originals, 16 previously absent files in total. Every copied private SHA256 equals its current-main source SHA256. No existing different file was overwritten, no BOM was stripped, no test logic or product asset was changed. Main remained untouched.

Executed isolated headless asset_pipeline_dependency_fixed at 2026-10-08 00:50:17–00:50:18 UTC: 79/79 assertions, exit 0, diagnostics empty. This validates source byte archives, decoded pixel equality, current import pixels, atlas crop and destination hashes. It does not establish gameplay or native art acceptance. The earlier failed strict result remains rejected; the root integrator owns how the focused replacement result is recorded alongside the remaining strict stages.

Evidence outside product: spell_work/ASSET_PIPELINE_FIXTURE_RECEIPT.json lists every path, initial absence, byte count and matching SHA256. Original failed stdout/stderr/combined logs are preserved in spell_work/asset_pipeline_baseline_rejected. Passing raw stdout/stderr/RUN_RESULT remain in probes/asset_pipeline_dependency_fixed.

These bytes already exist in main. They are private QA dependencies, not an outgoing merge payload. Future isolated checkouts must preserve the manifest and its referenced archival dependencies even when skipping the rest of docs/verification.
