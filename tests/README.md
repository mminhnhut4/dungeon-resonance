# Index kiểm thử

Index giúp tìm suite theo phần việc; file và UID vẫn ở đường dẫn hiện tại. Nhóm dưới đây dựa vào tên hiện có để điều hướng, không tuyên bố boundary kiến trúc hoặc tự thêm suite vào runner.

## Cách dùng

Đọc [AGENTS.md](../AGENTS.md), [quyết định hiện hành](../docs/DECISIONS.md) và [nhật ký](<../nhật ký vấp ngã/README.md>) trước khi chọn kiểm. [run_tests.ps1](run_tests.ps1) là strict gate hiện hữu; GameplayOnly là chẩn đoán, không phải strict gate hoàn chỉnh. Chọn kiểm hẹp theo seam của thay đổi và chỉ dẫn mới của người dùng; không chạy cả gate để xác nhận trạng thái hoặc thay đổi docs.

Đặt profile/AppData/evidence vào QA root riêng; giữ lỗi và log thô. Capture/preview cần điều kiện GPU riêng và không được coi là bài kiểm headless mặc định. Không chạy các script tương tác khi chưa biết tham số và quyền sở hữu tiến trình.

Snapshot navigation hiện tại: **143 file GDScript**, **97 file được runner tham chiếu tĩnh**. Số này không phải số assertion, coverage hay kết quả pass. Các suite mới như aggro/layout có thể được chạy focused riêng dù chưa nằm trong danh sách strict cũ. Việc đổi registry/runner là phạm vi khác.

Xem [kế hoạch phase1 docs/tests](../docs/architecture/PHASE1_DOCS_TESTS_PLAN.md).

## Input và movement

- [movement_test.gd](movement_test.gd)
- [movement_visual_test.gd](movement_visual_test.gd)
- [travel_clocks_test.gd](travel_clocks_test.gd)
- [traversal_lab_test.gd](traversal_lab_test.gd)

## Combat, quái và VFX

- [affliction_visuals_test.gd](affliction_visuals_test.gd)
- [boss_peak_readability_test.gd](boss_peak_readability_test.gd)
- [combat_juice_test.gd](combat_juice_test.gd)
- [combat_polish_test.gd](combat_polish_test.gd)
- [combat_test.gd](combat_test.gd)
- [combat_visuals_test.gd](combat_visuals_test.gd)
- [combined_aggro_layout_test.gd](world/dungeon/combined_aggro_layout_test.gd)
- [damage_numbers_test.gd](damage_numbers_test.gd)
- [death_ground_test.gd](death_ground_test.gd)
- [dynamic_vfx_test.gd](dynamic_vfx_test.gd)
- [enemy_art_test.gd](enemy_art_test.gd)
- [enemy_attack_vfx_test.gd](enemy_attack_vfx_test.gd)
- [guard_body_frames_test.gd](guard_body_frames_test.gd)
- [hit_reaction_test.gd](hit_reaction_test.gd)
- [opening_enemy_audit.gd](opening_enemy_audit.gd)
- [opening_enemy_polish_test.gd](opening_enemy_polish_test.gd)
- [reactive_enemy_aggro_test.gd](reactive_enemy_aggro_test.gd)
- [vfx_test.gd](vfx_test.gd)
- [world_enemy_test.gd](world_enemy_test.gd)

## Gear, rune và cộng hưởng

- [armor_test.gd](armor_test.gd)
- [crafting_test.gd](crafting_test.gd)
- [gear_test.gd](gear_test.gd)
- [inventory_equipment_test.gd](inventory_equipment_test.gd)
- [item_icon_test.gd](item_icon_test.gd)
- [loot_affix_test.gd](loot_affix_test.gd)
- [modular_equipment_test.gd](modular_equipment_test.gd)
- [relics_test.gd](relics_test.gd)
- [resonance_test.gd](resonance_test.gd)
- [spell_matrix_test.gd](spell_matrix_test.gd)
- [talisman_light_readability_test.gd](talisman_light_readability_test.gd)
- [weapon_content_test.gd](weapon_content_test.gd)
- [world_weapons_test.gd](world_weapons_test.gd)

## Opening, NPC, nhiệm vụ và Camp

- [campfire_audio_test.gd](campfire_audio_test.gd)
- [campfire_guide_coexist_test.gd](campfire_guide_coexist_test.gd)
- [campfire_ui_test.gd](campfire_ui_test.gd)
- [cultivation_styles_test.gd](cultivation_styles_test.gd)
- [map_quest_test.gd](map_quest_test.gd)
- [npc_dialogue_test.gd](npc_dialogue_test.gd)
- [npc_lived_opening_test.gd](npc_lived_opening_test.gd)
- [npc_population_test.gd](npc_population_test.gd)
- [opening_anchor_process_probe.gd](opening_anchor_process_probe.gd)
- [opening_combined_owner_test.gd](opening_combined_owner_test.gd)
- [opening_cultivation_gameplay_test.gd](opening_cultivation_gameplay_test.gd)
- [opening_cultivation_state_test.gd](opening_cultivation_state_test.gd)
- [opening_dungeon_route_test.gd](world/dungeon/opening_dungeon_route_test.gd)
- [opening_loop_test.gd](opening_loop_test.gd)
- [opening_npc_life_adapter_test.gd](opening_npc_life_adapter_test.gd)
- [opening_owner_review_r2_test.gd](opening_owner_review_r2_test.gd)
- [opening_product_process_probe.gd](opening_product_process_probe.gd)
- [opening_progression_guide_test.gd](opening_progression_guide_test.gd)
- [opening_qa_gate_test.gd](opening_qa_gate_test.gd)
- [opening_quest_cards_test.gd](opening_quest_cards_test.gd)
- [opening_runtime_wiring_test.gd](opening_runtime_wiring_test.gd)
- [opening_style_binding_test.gd](opening_style_binding_test.gd)
- [progression_acquisition_repro_test.gd](progression_acquisition_repro_test.gd)
- [prologue_hub_test.gd](prologue_hub_test.gd)
- [prologue_render_benchmark.gd](prologue_render_benchmark.gd)
- [prologue_visual_test.gd](prologue_visual_test.gd)
- [starter_character_test.gd](starter_character_test.gd)
- [starter_flow_test.gd](starter_flow_test.gd)
- [storyteller_test.gd](storyteller_test.gd)

## World, dungeon và tuyến ngoài trời

- [alpha_test.gd](alpha_test.gd)
- [campaign_test.gd](campaign_test.gd)
- [dungeon_layout_test.gd](world/dungeon/dungeon_layout_test.gd)
- [exterior_route_test.gd](exterior_route_test.gd)
- [foyer_art_test.gd](foyer_art_test.gd)
- [world_render_benchmark.gd](world_render_benchmark.gd)

## Save, transaction và kinh tế

- [economy_test.gd](economy_test.gd)
- [opening_profile_process_probe.gd](opening_profile_process_probe.gd)
- [opening_profile_writer_test.gd](opening_profile_writer_test.gd)
- [opening_progression_recovery_test.gd](opening_progression_recovery_test.gd)
- [opening_scope_migration_test.gd](opening_scope_migration_test.gd)
- [opening_social_quarantine_test.gd](opening_social_quarantine_test.gd)
- [profile_json_spans_test.gd](profile_json_spans_test.gd)
- [sanctuary_test.gd](sanctuary_test.gd)
- [save_transaction_test.gd](save_transaction_test.gd)
- [world_economy_test.gd](world_economy_test.gd)

## Audio, UI và trình bày

- [antique_icon_catalog_audit.gd](antique_icon_catalog_audit.gd)
- [antique_service_ui_test.gd](antique_service_ui_test.gd)
- [audio_quit_test.gd](audio_quit_test.gd)
- [audio_test.gd](audio_test.gd)
- [audio_weight_test.gd](audio_weight_test.gd)
- [character_feedback_test.gd](character_feedback_test.gd)
- [full_visual_hud_test.gd](full_visual_hud_test.gd)
- [full_visual_props_test.gd](full_visual_props_test.gd)
- [game_feel_test.gd](game_feel_test.gd)
- [modular_rig_test.gd](modular_rig_test.gd)
- [pilgrimage_audio_test.gd](pilgrimage_audio_test.gd)
- [pilgrimage_presentation_test.gd](pilgrimage_presentation_test.gd)
- [player_art_test.gd](player_art_test.gd)
- [player_polish_test.gd](player_polish_test.gd)
- [player_rig_test.gd](player_rig_test.gd)
- [polish_render_benchmark.gd](polish_render_benchmark.gd)
- [polish_test.gd](polish_test.gd)
- [region_ui_probe_test.gd](region_ui_probe_test.gd)
- [slice_presentation_lifetime_test.gd](slice_presentation_lifetime_test.gd)
- [two_column_service_ui_test.gd](two_column_service_ui_test.gd)
- [ui_ux_test.gd](ui_ux_test.gd)

## Hạ tầng và contract khác

- [addon_test.gd](addon_test.gd)
- [asset_pipeline_test.gd](asset_pipeline_test.gd)
- [conditions_test.gd](conditions_test.gd)
- [content_data_test.gd](content_data_test.gd)
- [content_render_benchmark.gd](content_render_benchmark.gd)
- [debug_overlay_lifetime_test.gd](debug_overlay_lifetime_test.gd)
- [high_fidelity_render_benchmark.gd](high_fidelity_render_benchmark.gd)
- [integration_fixtures/reviewed_opening/courier_opportunity.gd](integration_fixtures/reviewed_opening/courier_opportunity.gd)
- [integration_fixtures/reviewed_opening/courier_progress.gd](integration_fixtures/reviewed_opening/courier_progress.gd)
- [integration_fixtures/reviewed_opening/social_catalog.gd](integration_fixtures/reviewed_opening/social_catalog.gd)
- [integration_fixtures/reviewed_opening/social_life_owner.gd](integration_fixtures/reviewed_opening/social_life_owner.gd)
- [integration_fixtures/reviewed_opening/social_progress.gd](integration_fixtures/reviewed_opening/social_progress.gd)
- [milestone_test.gd](milestone_test.gd)
- [procedural_actors_test.gd](procedural_actors_test.gd)
- [region_entry_card_test.gd](region_entry_card_test.gd)
- [render_benchmark.gd](render_benchmark.gd)
- [survival_test_base.gd](survival_test_base.gd)
- [validate_project.gd](validate_project.gd)

## Capture, preview và fixture chuyên biệt

- [addon_cleanup_entrypoints.gd](addon_cleanup_entrypoints.gd)
- [addon_cleanup_lifecycle.gd](addon_cleanup_lifecycle.gd)
- [guard_body_frames_preview.gd](guard_body_frames_preview.gd)
- [guard_contact_timing_preview.gd](guard_contact_timing_preview.gd)
- [neutral_equipment_fixture.gd](neutral_equipment_fixture.gd)
- [npc_visual_capture.gd](npc_visual_capture.gd)
- [opening_aggro_route_preview.gd](opening_aggro_route_preview.gd)
- [pilgrimage_audio_mix_capture.gd](pilgrimage_audio_mix_capture.gd)
- [pilgrimage_preview.gd](pilgrimage_preview.gd)
- [pilgrimage_visual_capture.gd](pilgrimage_visual_capture.gd)
- [preview_art.gd](preview_art.gd)
- [preview_combat.gd](preview_combat.gd)
- [preview_combat_art.gd](preview_combat_art.gd)
- [preview_content.gd](preview_content.gd)
- [preview_dynamic_polish.gd](preview_dynamic_polish.gd)
- [preview_high_fidelity.gd](preview_high_fidelity.gd)
- [preview_inventory.gd](preview_inventory.gd)
- [preview_movement_visual.gd](preview_movement_visual.gd)
- [preview_polish.gd](preview_polish.gd)
- [preview_prologue.gd](preview_prologue.gd)
- [preview_resonance.gd](preview_resonance.gd)
- [preview_starter_character.gd](preview_starter_character.gd)
- [preview_world_building.gd](preview_world_building.gd)
