Dungeon Resonance — P01 pilot_traveler articulated walking candidate v1

RESULT
One bounded exemplar for the existing traveler NPC, made from 12 separately
generated body layers. There are 8 distinct articulated walk poses, with
alternating feet, independent hip/knee changes, opposing arm swing, and slight
body weight/luggage motion. This is not duplicated or bobbed whole-body idle art.

STATUS: CANDIDATE REQUIRING IN-GAME VISUAL REVIEW.
The art and motion are usable for a trial, but this is not a claim of final
production approval. Shoulder/knee cutout joins and layered tunic hems remain
noticeable at inspection scale. The resulting costume is slightly bulkier than
the idle reference. No second generation was used to polish these differences.
Foot locking and possible foot sliding must also be judged at the real game's
movement speed; this standalone art preview cannot verify world-space locomotion.
Do not automatically replace the already delivered idle art or the entire NPC
roster. P02/P03 and all previously delivered idle files are unchanged.

ART AND SCOPE
One built-in image_gen call created the new separated parts, using the saved
original pilot_traveler idle as its visual reference. Image_gen created the
visuals. Subsequent work only cropped, rigged, transformed, resampled and packed
those generated layers; no painted placeholders or procedural character art.
The source sheet, exact generation prompt, individual parts and parts atlas are
included. No user-PC asset was read, exported, modified or installed. No Golem
work was performed. No Windows-project integration or runtime test is claimed.

QUICK SPRITE-SHEET USE
runtime/pilot_traveler_walk_atlas.png: RGBA 2048x288, eight horizontal frames.
Each frame is 256x288 with ground pivot (128,272), top-left-origin coordinates.
Frame n has rectangle [256*n, 0, 256, 288]. Render at 64x72 for about a 60px body.
Place top-left at (world_foot_x-32, world_foot_y-68) at that size.
runtime/pilot_traveler_walk_atlas_60px.png: pre-scaled RGBA 512x72, eight 64x72
frames, ground pivot (32,68). Both atlases face right; mirror around the ground
pivot for left-facing movement. Use linear filtering and clamp texture edges.

CLIP
8 frames, 100ms per frame, 10fps, 800ms looping clip.
Contact events: near foot at 0ms, far foot at 400ms.
Pose order: near contact; near load/far lift; near support/far passing;
near push/far extension; far contact; far load/near lift;
far support/near passing; far push/near extension.
Footstep sound events can follow the contact times, subject to the actual game's
movement-speed and pause/restart logic. No audio was added in this package.

BODY-LAYER USE
runtime/traveler_parts_atlas.png contains 12 parts. Do not assume regular-grid
rectangles: use each exact atlas_rect in manifest.json. Individual PNGs are also
provided. attachment_points_local and pivot_local use pixels inside each part.
Every key contains layer_transforms in draw order, using Canvas2D matrix form
[a,b,c,d,e,f]. These transform the corresponding local part PNG into the 256x288
frame. The knee flexion values and phase keys may instead guide adaptation to
the game's existing bone-motion system. Avoid layering both baked walk frames
and live body parts simultaneously.

VERIFICATION
- 12 nonempty RGBA parts, real alpha, valid finite geometry and local pivots.
- 8 unique rendered frames; knee flexion spans 0 to 67 degrees on both legs.
- All significant foot silhouettes finish at the same y=272 ground boundary.
- Transparent outer border on every frame; no sprite edge clipping.
- At least 99.97% of significant alpha belongs to one connected body in every
  frame; no detached limb component larger than four pixels was detected.
- All eight poses were visually inspected in the contact sheet. Game-size and
  enlarged preview renders were checked; the GIF structure has eight frames.
- Existing idle package checksums still pass.

REVIEW ARTIFACTS
qa/traveler_walk_preview.gif: animated preview at game size and 3x inspection.
qa/traveler_walk_contact_sheet.png: all eight poses together.
qa/validation.json and qa/connectivity.json: geometry/alpha checks.
manifest.json: exact rectangles, pivots, timing, anchors and transform keys.

STOPPING POINT
This task used exactly one new image generation and produced this one candidate.
Further asset generation, broader roster work or production approval requires a
separate decision. Preserve the idle fallback if this candidate is rejected.
