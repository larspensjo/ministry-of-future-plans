## Dark theme

Since terminals lack the ability to draw soft shadows or gradients, we must use **Contrast** and **Color Weight** to simulate depth and hierarchy.

Here is a recommendation for mapping your GUI theme to the Terminal environment:

### 1. The Palette Mapping
We should stick to the standard 16-color ANSI palette for maximum compatibility, mapping your GUI colors to the nearest terminal equivalents.

*   **Background:** `Black` (Standard terminal background).
*   **Base Text:** `Gray` (In terminals, "Gray" is actually a soft white/light grey, whereas "White" is brilliant white. Use `Gray` to reduce eye strain, matching your `#E0E5EC` off-white).
*   **Highlights/Active:** `Cyan` (Matches your `#00C9FF` neon liquid/soft blue).
*   **Headers/Labels:** `Yellow` or `DarkYellow` (Matches your `#FFB347` Amber).
*   **Muted/Inactive:** `DarkGray` (Crucial for the "recessed" look).

### 2. Visual Hierarchy Strategy

In a text interface, you can't use "inset shadows." Instead, you use **brightness** to indicate depth.

**Layer 1: The Framework (Darkest)**
Use `DarkGray` for anything structural that the user doesn't need to read.
*   **Pane Borders:** The vertical lines and headers of inactive panes.
*   **The Scrollbar Track:** The space where the scrollbar isn't.
*   **IDs:** In the Idea list, the `FI-Architecture-...` ID is metadata. Color it `DarkGray` so the **Title** pops out.

**Layer 2: The Content (Mid-Tone)**
Use `Gray` (Soft White) for the actual data.
*   The titles of the ideas.
*   The tag names.
*   The body text in the Detail view.

**Layer 3: The Focus (Brightest)**
Use `Cyan` or `White` to indicate "This is active."
*   **The Cursor:** The `>` character.
*   **Active Selection:** The text of the line currently selected.
*   **Active Pane Header:** The title of the pane (e.g., `[Ideas]`) should turn `Cyan` when you tab into it, and fade to `DarkGray` when you tab away.

### 3. Improving List Readability

Looking at your screenshot, the "Ideas" list is dense. Here is how to break it up using color:

**A. Semantic Coloring (The "Traffic Light" system)**
Don't just write `Priority: P2`. Color code specific data points so you can scan them without reading.
*   **Priority:**
    *   **P0/P1:** `Red` or `Magenta` (Urgent).
    *   **P2:** `Yellow` (Warning/Caution).
    *   **P3:** `Green` or `DarkCyan` (Safe/Later).
*   **Risk:**
    *   **High:** `Red`.
    *   **Medium:** `Yellow`.
    *   **Low:** `DarkGray` (Low risk isn't interesting, fade it out).

**B. The "Dimmed" ID**
Currently, `FI-Architecture-DownloadPipeline-0001` takes up a lot of visual weight.
*   **Recommendation:** Print the ID in `DarkGray` and the Title in `Gray` (or `White` if selected). This simulates the ID being "recessed" into the background.

### 4. The Scrollbar & Cursor Column (Specific Request)

You asked about the scrollbar overlapping the cursor. Here is the aesthetic recommendation:

*   **The Track (Empty space):** Draw a `│` (Light Vertical) in `DarkGray`. This creates a subtle "groove" down the left side, mimicking your GUI's "Inner Shadow."
*   **The Scroll Thumb:** Draw a `┃` (Heavy Vertical) in `Gray` (not White). It should look metallic/soft, not glowing.
*   **The Cursor (`>`):** Draw this in **Bold Cyan**.
*   **Interaction:** Since the Cursor sits "on top" of the scrollbar:
    *   If the cursor is on row 5, row 5 gets a Cyan `>`.
    *   Row 6 gets a Gray `┃` (part of the thumb).
    *   Row 1 gets a DarkGray `│` (part of the track).

### 5. The Details Pane

To make the text block at the bottom readable:
*   **Labels:** Color the keys (e.g., `Summary:`, `Rationale:`) in `DarkYellow` (Amber). This acts as an anchor for the eye.
*   **Values:** Color the actual text in `Gray`.
*   **Keywords:** If you can parse markdown, highlight bold text (`**text**`) in `White` to make it pop against the `Gray` body.

### Summary of proposed Color Map

| UI Element | Color | Reasoning |
| :--- | :--- | :--- |
| **Active Header** | `Cyan` | Matches your GUI's "Neon Liquid" accent. |
| **Inactive Header** | `DarkGray` | Simulates a recessed/inactive state. |
| **Scroll Thumb** | `Gray` | "Soft" button look. |
| **Scroll Track** | `DarkGray` | Simulates the "Groove." |
| **Idea ID** | `DarkGray` | De-emphasize metadata. |
| **Idea Title** | `Gray` | Standard readable text (Off-white). |
| **Selected Line** | `White` on `DarkCyan` (bg) | High contrast focus. |
| **High Priority** | `Red` | Immediate visual signal. |

This scheme respects your "Tactile Depth" philosophy: lighter items feel closer (Active/Cursor), darker items feel further away (IDs/Borders/Inactive).
