# B0XazUI

A **UI engine for Roblox built entirely at runtime** — no Studio, no place file, no
pre-authored ScreenGui. You hand it a config table, it builds the instance tree.

It is a *library*, not a script: it creates frames, labels and buttons, wires up input,
and hands you callbacks. It contains no game-specific behaviour of any kind.

The default skin is **Abyss** — the skeet-inspired look the engine was designed for:
square edges, one-pixel borders, tiny text, a blurple accent, sections whose title
sits on their top border, and a two-column page layout:
[`examples/Abyss.lua`](examples/Abyss.lua) recreates the original reference window
element for element.

```
+---------------------------------------------------------------+
| abyss dev access |  da hood                              -  x |  title strip
+---------------------------------------------------------------+
| +-----+                                                       |
| |main |  rage                                                 |  boxed tabs
+------+--------------------------------------------------------+
|  legit ---------------------------  drawing field of view -----+----------------+
| +--------------------------------+ +----------------------------+             |
|   [x] aimbot                [ M2 ]   [x] aimbot fov        ======== swatch      |
|   [ ] visible check                size                     value overlay      |
|   [ ] apply prediction           +-------------------------------------------+ |
|   smoothing [mouse]              |                 100/250                    | |
| +--------------------------------+ +-------------------------------------------+ |
| |                    0/20        |                                            | |
| +--------------------------------+ +----------------------------+             |
+---------------------------------------------------------------+
 ===============================================================   accent strip
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
│   ├── Theme.lua                every colour, font and metric in one table (the Abyss skin)
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
│   │   ├── Window.lua           title strip + tab bar + content shell + accent strip
│   │   ├── Tab.lua              boxed tab button + scrolling page with N columns
│   │   ├── Section.lua          fieldset box whose title sits on its top border
│   │   └── Notification.lua     stacked toasts
│   │
│   └── Elements/
│       ├── Label.lua
│       ├── Button.lua           flat bordered box
│       ├── Toggle.lua           accenting checkbox, optional key chip + colour swatch
│       ├── Slider.lua           bordered bar with the value/max reading on it
│       ├── Dropdown.lua         label + bordered box ("+"), expands inline
│       ├── Textbox.lua          label + full-width inset box, numeric filter option
│       ├── Keybind.lua          key chip: capture + hotkey firing
│       └── ColorPicker.lua      swatch block; popup with HSV field, hue strip, hex
│
├── examples/Demo.lua            every element, wired up
├── examples/Abyss.lua           the original reference window, element for element
├── preview/                     ← browser render of the live instance tree
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
| `Window:AddTab(name, config)` | `config.Columns` — page columns (default `2`); use `1` for a single stack |
| `Tab:AddSection(title, config)` | `config.Column` — which column the section lands in (default `1`); `config.Collapsed = true` starts collapsed |
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
| **Toggle** | `Name`, `Default`, `Callback` · `:Toggle()` — plus `Bind` (KeyCode/UserInputType) to draw the `[ M2 ]` key chip: click to rebind, Escape clears, the key toggles the toggle. And `Swatch = { Default, Callback }` to embed a colour swatch |
| **Slider** | `Name`, `Min`, `Max`, `Default`, `Step`, `Suffix`, `Callback` · reads `value/max` centred on the bar · `:SetRange(min, max)` |
| **Dropdown** | `Name`, `Options`, `Default`, `Multi`, `MaxVisible`, `Callback` · selection shown inside the box, `+` opens the inline list · `:SetOptions()`, `:AddOption()`, `:RemoveOption()`, `:SetOpen()` |
| **Textbox** | `Name`, `Default`, `Placeholder`, `Numeric`, `MaxLength`, `ClearOnFocus`, `Callback(text, enterPressed)` · `:GetNumber()` |
| **Keybind** | `Name`, `Default` (KeyCode), `Callback` · chip on the right, click to listen · `:StartListening()`, `:SetKey()`, `:GetName()`, `:Matches(input)` |
| **ColorPicker** | `Name`, `Default` (Color3), `Callback` · swatch + popup · `ColorPicker.NewSwatch(container, { Position, Default, Callback })` for embedding |

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
    Font       = Enum.Font.Gotham, -- trade the tiny mono face back in
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

Window chrome and disclosure glyphs are **plain ASCII** — `-`, `+`, `x` — so every
font Roblox ships renders them, and they are exactly what the original design uses.
Only the four notification-type icons are **emoji**, drawn in colour by the platform
emoji font (desktop and mobile alike) on a tinted backdrop, since `TextColor3`
cannot tint an emoji:

```lua
UI:SetTheme({ Icons = { Success = "\u{2705}", Close = "\u{2716}\u{FE0F}" } })
```

Roblox renders its UI text without glyphs for most symbol blocks — dingbats
(`\u{2713}` `\u{2715}`), geometric shapes (`\u{25BE}` `\u{25B8}`) and box drawing all
come back as an empty box. Sticking to ASCII + emoji keeps every glyph honest.

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

Three phases run, each in a fresh Lua VM:

1. **`examples/Demo.lua`** — proves the documented API works end to end.
2. **`examples/Abyss.lua`** — the reference-window recreation builds cleanly.
3. **`tests/spec.lua`** — 71 assertions over loading, the window shell, columns,
   every element's input handling, chips and swatches, notification layout, icons,
   theming, tree integrity and teardown.

```
71 passed, 0 failed
```

### Seeing it without Roblox

The same mocked client can dump the built instance tree to JSON and render it in a
browser with the exact layout maths the engine uses:

```bash
node tests/preview.js    # writes preview/data.json + data.js from examples/Abyss.lua
# then either serve the folder...
python3 -m http.server -d preview
# ...or just open preview/index.html directly — data.js makes file:// work too
```

---

## License

MIT.
