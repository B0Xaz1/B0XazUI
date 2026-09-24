# B0XazUI

A **UI engine for Roblox built entirely at runtime** — no Studio, no place file, no
pre-authored ScreenGui. You hand it a config table, it builds the instance tree.

It is a *library*, not a script: it creates frames, labels and buttons, wires up input,
and hands you callbacks. It contains no game-specific behaviour of any kind.

```
┌────────────────────────────────────────┬───────┐
│ B0XazUI  v1.0.0              [ – ] [ ✕ ]│ topbar│  draggable
├────────────────────────────────────────┼───────┤
│  Home   Visuals   Settings              │ tabs  │  horizontal tab bar
├────────────────────────────────────────┴───────┤
│ ┌────────────────────────────────────────────┐ │
│ │ WELCOME                                 ▾  │ │  section
│ │ A UI engine built out of Instances…        │ │  label
│ ├────────────────────────────────────────────┤ │
│ │ [              Say hello                 ] │ │  button
│ ├────────────────────────────────────────────┤ │
│ │ Enabled                            [ ●━━] │ │  toggle
│ │ Walk speed                    42 studs     │ │  slider
│ │ ━━━━━━━━━●────────────────────────────     │ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

---

## Quick start

```lua
local B0XazUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/B0Xaz1/B0XazUI/main/init.lua"
))()

local UI = B0XazUI:Load()

local Window = UI:CreateWindow({ Title = "My UI", Size = Vector2.new(620, 460) })
local Tab   = Window:AddTab("Home")
local Sec   = Tab:AddSection("Settings")

Sec:AddToggle({ Name = "Enabled", Default = false, Callback = function(value)
    print(value)
end })
```

That is the whole API surface: **load → window → tab → section → elements**.

---

## Repository layout

`init.lua` sits at the root of the repo and is the only file you load. It pulls down
everything under `Core/` in dependency order and injects a shared namespace into each
module.

```
B0XazUI/
├── init.lua                     ← entry point (this is what loadstring() fetches)
├── Core/                        ← the engine module tree
│   ├── Env.lua                  executor detection: gethui / protect_gui / HTTP / task
│   ├── Theme.lua                every colour, font and metric in one table
│   ├── Library.lua              namespace assembly: ScreenGui, overlay, theme registry
│   │
│   ├── Util/
│   │   ├── Color.lua            hex ⇄ RGB ⇄ HSV, mixing, readable-text picking
│   │   ├── Signal.lua           minimal event + Bin (bulk cleanup of connections)
│   │   ├── Tween.lua            TweenService wrapper with per-instance cancel
│   │   ├── Create.lua           instance factory (properties → children → parent, last)
│   │   ├── Draggable.lua        window dragging with on-screen clamping
│   │   ├── Layout.lua           auto-size / auto-canvas-size binding, text measuring
│   │   └── Popup.lua            overlay-parented floating panels (no clipping)
│   │
│   ├── Components/
│   │   ├── Window.lua           topbar + tab bar + content shell
│   │   ├── Tab.lua              tab button + scrolling page
│   │   ├── Section.lua          collapsible element group
│   │   └── Notification.lua     stacked toasts
│   │
│   └── Elements/
│       ├── Label.lua
│       ├── Button.lua           with material-style ripple
│       ├── Toggle.lua
│       ├── Slider.lua           drag + click-on-track, min/max/step
│       ├── Dropdown.lua         single & multi select, expands inline
│       ├── Textbox.lua          optional numeric filtering + max length
│       ├── Keybind.lua          key capture + hotkey firing
│       └── ColorPicker.lua      HSV field, hue strip, editable hex
│
├── examples/Demo.lua            every element, wired up
└── tests/                       mocked-Roblox harness (see below)
```

### Module contract

Every file under `Core/` returns one function that receives the shared namespace:

```lua
-- Core/Elements/MyElement.lua
return function(UI)
    local MyElement = {}
    MyElement.__index = MyElement

    function MyElement.New(section, config)
        -- build frames, return an object with :SetValue / :Destroy / etc.
    end

    MyElement.new = MyElement.New
    UI.Elements.MyElement = MyElement   -- registers Section:AddMyElement()
end
```

Adding a module is two steps: write the file, add its path to `MODULES` in `init.lua`.
`Core/Library.lua` then generates `Section:AddMyElement()` for free.

---

## API

### Namespace

| Call | Returns | Notes |
|---|---|---|
| `B0XazUI:Load(options)` | `UI` | Fetches + builds. `options`: `Branch`, `Repo`, `BaseUrl`, `Force`, `Silent` |
| `B0XazUI:Get(options)` | `UI` | Returns the cached namespace, loading on demand |
| `B0XazUI:AddModule(path)` | `self` | Append your own module to the manifest |
| `UI:CreateWindow(config)` | `Window` | |
| `UI:Notify(config)` | `Notification` | `{ Title, Content, Duration, Type }` |
| `UI:SetTheme(overrides)` | — | Merges into the palette and repaints live elements |
| `UI:SetNotificationCorner(corner)` | — | `BottomRight`·`BottomLeft`·`TopRight`·`TopLeft` |
| `UI:ListElements()` | `{string}` | Introspection |
| `UI:Destroy()` | — | Tears down every window and the ScreenGui |

### Window

| Member | Notes |
|---|---|
| `:AddTab(name)` | Returns a `Tab`; the first tab is selected automatically |
| `:SelectTab(tabOrName)`, `:GetTab(name)` | |
| `:SetTitle(title, subtitle)` | |
| `:SetSize(width, height)` | |
| `:SetMinimized(bool)` | Collapses to just the topbar |
| `:SetVisible(bool)`, `:Toggle()`, `:IsVisible()` | |
| `:Center()` | |
| `:Notify(options)` | Passthrough to the namespace |
| `:Destroy()` | |

Config: `Title`, `SubTitle`, `Size` (Vector2), `Position` (UDim2, defaults to centred),
`Draggable`, `ToggleKey` (KeyCode), `OnClose`, `CloseDestroys`.

### Tab / Section

| Member | Notes |
|---|---|
| `Tab:AddSection(title, config)` | `config.Collapsed = true` starts collapsed |
| `Tab:GetSection(title)`, `Tab:SetName(name)`, `Tab:Clear()`, `Tab:Destroy()` | |
| `Section:Add<Element>(config)` | One per element type |
| `Section:Add("Toggle", config)` | Same thing, by name |
| `Section:SetExpanded(bool)`, `:SetTitle(text)`, `:SetVisible(bool)`, `:Clear()`, `:Destroy()` | |

### Elements

Every element returns an object with `:SetValue(v, skipCallback)`, `:GetValue()`,
`:SetVisible(bool)`, `:Destroy()`, a `.Changed` signal, and (where it makes sense)
`:SetText()`, `:SetCallback()`.

| Element | Config |
|---|---|
| **Label** | `Text`, `Style` (`Text`·`Dim`·`Faint`·`Accent`), `Bold`, `RichText`, `Wrapped`, `Align` |
| **Button** | `Name`, `Callback`, `Detail`, `Height`, `Disabled` · `:Fire()` |
| **Toggle** | `Name`, `Default`, `Callback` · `:Toggle()` |
| **Slider** | `Name`, `Min`, `Max`, `Default`, `Step`, `Suffix`, `Callback` · `:SetRange(min, max)` |
| **Dropdown** | `Name`, `Options`, `Default`, `Multi`, `MaxVisible`, `Callback` · `:SetOptions()`, `:AddOption()`, `:RemoveOption()`, `:SetOpen()` |
| **Textbox** | `Name`, `Default`, `Placeholder`, `Numeric`, `MaxLength`, `ClearOnFocus`, `Callback(text, enterPressed)` · `:GetNumber()` |
| **Keybind** | `Name`, `Default` (KeyCode), `Callback` · `:StartListening()`, `:SetKey()`, `:GetName()`, `:Matches(input)` |
| **ColorPicker** | `Name`, `Default` (Color3), `Callback` · `:SetOpen()` |

Options may be plain strings or `{ Text = "Fast", Value = 1 }` tables.

---

## Theming

`Core/Theme.lua` holds the entire palette. Either edit it directly, or retheme at
runtime — every element registers its themed properties, so one call repaints the
whole UI:

```lua
UI:SetTheme({
    Accent     = Color3.fromRGB(255, 90, 90),
    Background = Color3.fromRGB(14, 14, 18),
    Text       = Color3.fromRGB(235, 235, 245),
})
```

---

## Executor compatibility

`Core/Env.lua` probes the environment and picks the best available option at each
step, so the same build runs everywhere:

| Need | Order of preference |
|---|---|
| GUI parent | `gethui()` → `get_hidden_gui()` → `CoreGui` (+ `syn.protect_gui`) → `PlayerGui` |
| HTTP | `game:HttpGet` → `syn.request` → `http_request` → `request` → `fluxus.request` |
| Scheduling | `task.*` → `wait` / `spawn` |
| Mouse position | `UserInputService:GetMouseLocation()` → `LocalPlayer:GetMouse()` |

No external assets: corners are `UICorner`, strokes are `UIStroke`, and the colour
picker's gradients are `UIGradient`s. Nothing to download, nothing to break.

### Icons

Every icon the engine draws lives in `Theme.Icons` and is an **emoji**:

```lua
UI:SetTheme({ Icons = { Success = "\u{2705}", Close = "\u{2716}\u{FE0F}" } })
```

Roblox renders its UI in the Gotham family, which has no glyph for most of the
symbol blocks — dingbats (`\u{2713}` `\u{2715}`), geometric shapes (`\u{25BE}`
`\u{25B8}`) and box drawing all come back as an empty box. Emoji fall back to the
platform emoji font and render on desktop and mobile alike, so that is what the
engine uses.

The trade-off is that emoji are drawn **in colour**, so `TextColor3` does not tint
them. Where a status colour still has to read — a notification type, say — the emoji
sits on a tinted backdrop instead of relying on the glyph's own colour.

`tests/spec.lua` walks the live instance tree and fails the build if any rendered
string contains a non-ASCII character that did not come out of `Theme.Icons`, so a
new text glyph cannot sneak back in.

---

## Tests

Roblox cannot be run in CI, so the repo ships a mocked client instead — a fake
`Instance`/`Enum`/service layer with **validated property assignment**, which means a
typo like `BackgroundColour3` fails the build rather than silently doing nothing.

```bash
cd tests && npm install     # installs wasmoon (Lua 5.4 in WASM)
cd .. && node tests/run.js
```

Two phases run, each in a fresh Lua VM:

1. **`examples/Demo.lua`** — proves the documented API works end to end.
2. **`tests/spec.lua`** — 67 assertions over loading, the window shell, every element's
   input handling, notification layout, icons, theming, tree integrity and teardown.

```
67 passed, 0 failed
```

---

## License

MIT.
