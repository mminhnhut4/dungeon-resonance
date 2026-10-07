Dungeon Resonance — Road NPC idle fallback art v1

READY: Three original full-body right-facing NPC images with real transparency,
matching stable ground pivots and both high-resolution and 60px-body PNG exports.
NOT READY: A walking animation. Each NPC has exactly one honest idle frame.
Do not cycle, duplicate or bob the image and describe it as completed walk art.
Road movement can use these temporary images while a real walk cycle is authored.

P01 pilot_traveler: older traveler carrying a tied canvas pack, moss-green cloak.
P02 pilot_bridge_keeper: stocky bridge caretaker, blue-grey work coat and cap.
P03 pilot_pilgrim: older hooded pilgrim, ochre robe, beads and rolled cloth.
No wandering merchant is included. These are anonymous supporting NPCs.

FILES AND COORDINATES
runtime/road_npcs_idle_atlas.png is a 256x864 RGBA atlas: one column, three rows.
Rows are P01, P02, P03 in that order; each cell is 256x288.
Each frame's ground pivot is (128,272), top-left-origin pixel coordinates.
Draw the 256x288 frame at 64x72 for an approximately 60px-tall visible body.
For a world foot point (x,y), top-left draw position at this scale is (x-32,y-68).
The pre-scaled atlas is 64x216, with 64x72 cells and pivot (32,68).
Individual PNGs are provided for both sizes. Use linear filtering and clamp edges.
Mirror the sprite horizontally around its pivot for left-facing use.
The high-res frame uses 240px visible body height; no built-in cast shadow.
manifest.json gives exact atlas rectangles, IDs, pivots and source/export metadata.

QUALITY AND LIMITS
All three silhouettes and feet were inspected at 60px height on light/dark backgrounds.
Generated alpha is retained, including very faint (<6.3%) edge pixels; it was not
replaced with a flat backdrop. Significant silhouette alpha has transparent padding.
Minor character-scale normalization is mechanical crop, resize and transparent padding.
No manual painted placeholders, duplicated animation frames or procedural character art.
An initial six-pose generation was rejected as a walk cycle because repeated steps
did not provide a convincing complete gait. It is intentionally excluded from runtime.
The included source PNG contains only the final three idle poses.
This package has not been installed or verified in the user's Windows project.
No files from the user's PC were read or exported to produce these images.

ART PROVENANCE
Artwork was produced using the built-in image_gen tool for this task, then mechanically
exported for game use. Prompts are included in source/. No CLI/API image model was used.
