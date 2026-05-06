# Unity 2D Patterns — Skill Reference

## Project Structure
```
Assets/
├── Animations/          # Animation clips and controllers
│   └── Controllers/
├── Effects/             # Particle systems, VFX
├── Materials/           # Materials by category
├── Prefabs/             # Prefabs by category
│   ├── UI/
│   ├── Ship/
│   ├── Map/
│   └── Vehicles/
├── Scenes/              # One scene per game state
├── Scripts/             # C# scripts by category
│   ├── Systems/         # MonoBehaviour managers
│   ├── Models/          # Data classes, ScriptableObjects
│   ├── UI/              # UI controllers
│   ├── Utils/           # Helpers, extensions
│   └── Editor/          # Editor-only scripts
├── ScriptableObjects/   # SO asset instances
├── Sprites/             # Sprite assets by category
│   ├── UI/
│   ├── Ship/
│   ├── Map/
│   ├── Crew/
│   └── Vehicles/
├── SpriteAtlases/       # Sprite Atlas v2 assets
└── Tests/
    ├── EditMode/
    └── PlayMode/
```

## Architecture Patterns

### ScriptableObject-Based Game State
```csharp
// Data container — no MonoBehaviour needed
[CreateAssetMenu(fileName = "GameConfig", menuName = "Makin/Game Config")]
public class GameConfig : ScriptableObject
{
    public float baseCarrierSpeed = 5f;
    public int maxCrewSize = 120;
}

// System references the SO — no singleton needed
public class CarrierMovement : MonoBehaviour
{
    [SerializeField] private GameConfig _config;
    [SerializeField] private CarrierState _state; // another SO
}
```

### Event Channel Pattern (decoupled communication)
```csharp
[CreateAssetMenu(menuName = "Makin/Events/Void Event")]
public class VoidEventChannel : ScriptableObject
{
    private System.Action _listeners;
    public void Raise() => _listeners?.Invoke();
    public void Register(System.Action cb) => _listeners += cb;
    public void Unregister(System.Action cb) => _listeners -= cb;
}
```

### System Manager Pattern
```csharp
// Thin MonoBehaviour — logic in plain C# class
public class TimeManager : MonoBehaviour
{
    [SerializeField] private TimeState _state;
    [SerializeField] private VoidEventChannel _onTimeChanged;
    
    private TimeLogic _logic; // plain C# — testable
    
    void Awake() => _logic = new TimeLogic(_state);
    void Update() => _logic.Tick(Time.deltaTime);
}
```

## Unity MCP Batch Pattern
When creating multiple GameObjects or components, use batch_execute:
```
// Instead of 10 individual calls, batch them:
batch_execute([
  { tool: "manage_gameobject", action: "create", name: "Carrier" },
  { tool: "manage_components", action: "add", gameObject: "Carrier", component: "SpriteRenderer" },
  { tool: "manage_components", action: "set", gameObject: "Carrier", component: "SpriteRenderer", property: "sortingLayer", value: "Ship" }
])
```

## Sorting Layers (back to front)
1. Background — sky, distant ocean
2. Water — ocean surface, waves
3. Midground — islands, landmarks
4. Ship — carrier hull, deck
5. Foreground — close objects, overlays
6. Effects — particles, weather
7. UI — all UI elements

## Scene Organization
- `MainMenu` — title screen, settings
- `WorldMap` — carrier navigation, POIs, missions
- `CarrierInterior` — compartment management, crew
- `Mission` — active mission execution (loaded additively)
- `SharedUI` — persistent HUD (loaded additively, never unloaded)

## Assembly Definitions
- `Makin.Systems` — game systems (references Models)
- `Makin.Models` — data models, ScriptableObjects (no dependencies)
- `Makin.UI` — UI controllers (references Systems, Models)
- `Makin.Utils` — shared utilities (no dependencies)
- `Makin.Editor` — editor scripts (Editor only)
- `Makin.Tests.EditMode` — edit mode tests
- `Makin.Tests.PlayMode` — play mode tests
