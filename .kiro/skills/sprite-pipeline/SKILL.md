# Sprite Pipeline — Skill Reference

## Art Style: Clean Vector Military
- Flat colors with subtle gradients, clean 2px outlines
- Muted military palette (see below)
- Readable silhouettes at small sizes
- Reference: FTL, Shortest Trip to Earth, Highfleet tactical map

## Color Palette
| Name | Hex | Usage |
|------|-----|-------|
| Navy Dark | #1a2744 | Backgrounds, deep water |
| Navy Mid | #2d4a7a | Ship hull, UI panels |
| Steel Gray | #4a5568 | Metal, machinery |
| Light Gray | #718096 | Text, borders, inactive |
| Olive | #4a5e3a | Land, vegetation |
| Rust | #8b4513 | Damage, warnings |
| Amber | #d4a574 | Highlights, active states |
| Ocean Blue | #1e3a5f | Ocean surface |
| Sky | #87ceeb | Sky, atmosphere |
| Alert Red | #c53030 | Danger, critical |
| Safe Green | #38a169 | OK status, health |
| White | #f7fafc | Text, UI highlights |

## Folder Structure
```
Assets/Sprites/
├── UI/              # Buttons, panels, icons, HUD elements
├── Ship/            # Carrier hull, compartments, deck
├── Map/             # World map tiles, POIs, routes
├── Crew/            # Character portraits, status icons
├── Vehicles/        # Aircraft, boats, vehicles
├── Missions/        # Mission type icons, objectives
└── Effects/         # Explosion frames, smoke, weather
```

## Naming Convention
`<category>_<subject>_<variant>_<state>.png`

Examples:
- `ship_carrier_hull_normal.png`
- `ship_carrier_hull_damaged.png`
- `crew_portrait_captain_idle.png`
- `ui_button_primary_pressed.png`
- `map_poi_settlement_discovered.png`

## Import Settings (Unity)
| Setting | Value |
|---------|-------|
| Texture Type | Sprite (2D and UI) |
| Sprite Mode | Single (or Multiple for sheets) |
| Pixels Per Unit | 100 |
| Filter Mode | Bilinear |
| Compression | None (for pixel-perfect) or Low Quality |
| Max Size | 2048 |
| Generate Mip Maps | OFF |

## Sprite Atlas Configuration
- One atlas per category (UI, Ship, Map, etc.)
- Padding: 4px between sprites
- Allow Rotation: OFF (prevents visual artifacts)
- Tight Packing: ON
- Include in Build: ON

## Placeholder Sprites
When final art isn't ready, create placeholders:
- Solid rectangle in the correct palette color
- White text label describing what it represents
- Exact target dimensions
- Suffix: `_placeholder` (e.g., `ship_carrier_hull_placeholder.png`)

## Size Reference (at 100 PPU)
| Element | Approximate Size (units) |
|---------|--------------------------|
| Carrier (world map) | 2.0 x 0.5 |
| POI icon | 0.5 x 0.5 |
| Crew portrait | 1.0 x 1.0 |
| Vehicle icon | 0.8 x 0.4 |
| UI button | 2.0 x 0.6 |
| Map tile | 1.0 x 1.0 |
