# mortalpages Notebook Automation Suite & Studio App

Professional macOS automation suite and native SwiftUI application for generating hyperlinked digital journals and planners.

---

## 🎨 mortalpages Studio (macOS GUI App)

A standalone native macOS application installed directly in `/Applications/mortalpages Studio.app` (and linked in `~/Dev/scripts/mortalpages Studio.app`).

### Features:
1. **Template Studio (Zero Canva)** 🌟 *NEW*:
   - Complete in-app replacement for Canva! Design, edit, and compile 188-page digital journals directly inside the app.
   - **Template Library**: Master layout, Sidebar with 14 navigation tabs, Cover pages, Chapter selection with arrows, Template list (Index), Grids (Full, Blank+Grid, 1/3, 2/3), Lined paper (Spacious, Medium, Narrow), Dotted bullet journals, Monthly & Weekly Planners, and Yearly Habit Trackers.
   - **Visual Customizer**: Real-time sliders and color pickers for page canvas, line spacing, grid size, dot pitch, and tab styling.
   - **Live Source Code Editor**: Direct access to edit raw HTML & CSS with instant hot-reloading in the WebKit preview pane.
   - **Theme Engine**: Save custom color palettes and styling rules as reusable themes (Glass Light, Obsidian Dark, Earthy Beige, Pretty Pastel, or create your own).
   - **⚡ Autonomous 1-Click Compiler**: Compiles all 188 vector pages, stamps 2,800+ hyperlinks, chapter arrows, and watermarks, and outputs a customer-ready PDF in seconds—no external apps needed.

2. **Interactive Workspace (Generator)**:
   - Drag-and-drop Canva PDF exports and Master Templates.
   - One-click **"Detect Open Files"** automatically reads your active documents in Preview and Keynote.
   - Choose to generate an **Interactive Customer PDF**, sync the **Keynote Presentation**, or both simultaneously.
   - Real-time progress bar, timing stats, link count counter, and instant "Open in Finder" / "Preview PDF" buttons.

2. **Theme Presets Manager**:
   - Switch effortlessly between different themes in 1 click:
     - 🌟 **Glass Notebook (Light)**
     - 🌙 **Glass Notebook (Dark)**
     - 📜 **Glass Notebook (Beige)**
     - 🌸 **Pretty Pastel**
     - ☕ **Choco Mocha**
   - Save your current workspace configurations as new custom presets (persisted in JSON).

3. **Layout & Section Rules**:
   - Master layout page exclusion toggle (omits Canva Page 2 from final PDF).
   - Sidebar tab overlay crop width (60 pt default).
   - Chapter tab exclusion range (Pages 3..14 default) so native Canva colored tabs show through.
   - Chapter selection arrow buttons on Page 2 with automatic targeting to subchapter covers (45, 57, 69, 81, 93, 105, 117, 129, 141, 153, 165, 177).
   - Precision hitbox matching that mirrors sidebar tab dimensions and vertical placement.

4. **Watermark & Branding Studio (Canva-Style Customizer)**:
   - **Mode Selection**:
     - 📷 **Extract from Master Layout**: Crops embossed watermark from Canva layout page (Page 2).
     - ✍️ **Custom Styled Text**: Full Canva-like typographic and effect designer.
     - 🚫 **None / Disable**: Turn off watermarking completely if layout design requires no branding.
   - **Page Scope**: Apply to All Pages (including Cover), All Content Pages (exclude Cover), or Notes & Content Only (Pages 15+).
   - **Typography**: 14 editorial & Canva fonts (`Avenir Next`, `SF Pro Display`, `Georgia`, `Didot`, `Baskerville`, `Futura`, `Playfair Display`, `Palatino`, etc.), font size slider, weight (Light to Heavy), italic, letter spacing (tracking).
   - **Effects**:
     - ✨ **Glow**: Glow color, blur radius, and opacity.
     - 🌑 **Primary Drop Shadow**: Color, blur radius, opacity, offset X & Y.
     - 🌓 **Double Shadow**: Secondary ambient depth shadow (Canva style) with custom blur and offsets.
     - 🏷 **3D Emboss**: Dual top-highlight and bottom-shadow simulating embossed text pressed into paper.
   - **Container & Background Box**:
     - Container sizing: Auto-Fit Text vs Explicit Custom Width & Height.
     - Padding: Horizontal & Vertical padding sliders.
     - Background: Transparent vs Solid/Translucent color fill with alpha slider.
     - Border: Color, border width, and opacity.
     - Corner Radius: 0 (sharp) to 30 (pill shape).
   - **Positioning**:
     - Presets: Bottom Center, Bottom Left, Bottom Right, Top Center, Top Left, Top Right, Center Diagonal (-35°), Custom (X, Y).
     - Rotation angle slider (-180° to +180°) with quick presets (0°, -35°, -45°).
   - **Interactive Live Preview**:
     - Real-time WYSIWYG rendering.
     - Background switcher: Paper Cream, Glass Light, Dark Mode, Warm Beige, Transparency Grid.
     - Container Zoom view & Full Page Simulation view.
     - Preview Link Detector Neutralizer prevents macOS Preview from converting text to a browser link.

### Launching the App:
- Open from Applications: Double-click `/Applications/mortalpages Studio.app` or search Spotlight for `mortalpages Studio`.
- Open from Terminal: `open -a "mortalpages Studio"`

### Rebuilding the App:
If you customize the Swift source code in `~/Dev/scripts/mortalpages-studio/`:
```bash
~/Dev/scripts/mortalpages-studio/build_app.sh
```

---

## 🛠 Terminal & Command-Line Tools

For quick scripting or batch terminal workflows, all compiled CLI utilities remain available in `~/Dev/scripts`:

### 1. `mortalpages.sh` (Interactive CLI Runner)
```bash
~/Dev/scripts/mortalpages.sh
```

### 2. `pdf_hyperlink_engine` (⚡ Direct PDF Engine)
Transfers all interactive navigation tabs, chapter selection arrows, and watermark stamping in **~0.3 seconds**:
```bash
~/Dev/scripts/pdf_hyperlink_engine
```
Or with custom arguments:
```bash
~/Dev/scripts/pdf_hyperlink_engine --pdf "/path/to/canva.pdf" --template "/path/to/template.pdf"
```

### 3. `keynote_bg_swapper` (🖥 Keynote Automation)
Replaces backgrounds across all slides in Keynote, sends to back, and preserves sidebar icons:
```bash
~/Dev/scripts/keynote_bg_swapper
```
Slide test range:
```bash
~/Dev/scripts/keynote_bg_swapper --start 1 --end 5
```

---

## Directory Structure
```
~/Dev/scripts/
├── mortalpages Studio.app          -> Symlink to /Applications/mortalpages Studio.app
├── mortalpages-studio/             -> SwiftUI Native App Source Code
│   ├── App/                        -> Main app entry point & lifecycle
│   ├── Models/                     -> NotebookConfig & ThemePreset data structures
│   ├── Engine/                     -> PDFLinkEngine & KeynoteBridge
│   ├── Views/                      -> Generator, Layout, Watermark, Presets & Components
│   └── build_app.sh                -> One-click compilation & packaging script
├── pdf_hyperlink_engine.swift      -> Swift source for direct PDF generator
├── pdf_hyperlink_engine            -> Compiled standalone binary
├── keynote_bg_swapper.swift        -> Swift source for Keynote background automator
├── keynote_bg_swapper              -> Compiled standalone binary
├── mortalpages.sh                  -> Master interactive terminal menu
└── README.md                       -> This documentation
```
