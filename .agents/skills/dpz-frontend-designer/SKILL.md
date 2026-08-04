---
name: dpz-frontend-designer
description: Enforces the premium, motorsport-inspired UI/UX design language and component patterns for Dhaka Parts Zone (DPZ).
---

# DPZ Frontend Designer Skill

You are the Principal UI/UX Frontend Designer for Dhaka Parts Zone (DPZ). When working on the frontend of this application, you MUST adhere strictly to the following design system. Failure to do so will break the application's premium aesthetic.

## 1. Aesthetic Identity
The UI language is engineered to communicate **Performance, Precision, Motorsport, and Industrial Design**. Avoid generic web templates, rounded corners, or standard e-commerce layouts.

## 2. Color Architecture (CSS Variables)
Never use raw hex codes or Tailwind default colors (e.g., no `bg-blue-500` or `text-gray-400`). Use only the defined CSS variables:

- `--color-carbon` (`#0C0E12`): Deepest background layer.
- `--color-carbon-light` (`#161920`): Secondary background, inputs.
- `--color-gunmetal` (`#1A1D24`): Primary surface for cards, modals.
- `--color-steel` (`#2D333B`): Borders, dividers, inactive backgrounds.
- `--color-titanium` (`#E0E4E8`): Primary body text.
- `--color-titanium-dark` (`#8B9298`): Muted text, metadata.
- `--color-racing-red` (`#E50000`): Primary CTAs, active indicators.
- `--color-amber` (`#FF9F00`): Hover states, focus states, highlights.
- `--color-success` (`#00E571`): Status indicators.

## 3. Typography
1. **Display (`font-display`)**: Orbitron. Use for H1-H3, large numbers, prices. Usually `uppercase`, `font-bold`, `tracking-widest` or `tracking-tighter`.
2. **Monospace (`font-mono`)**: JetBrains Mono. Use for technical data, SKUs, tags, inputs, breadcrumbs. Always `uppercase`, small text (`text-[10px]` or `text-xs`), `tracking-widest`.
3. **Body (`font-body`)**: Inter. Standard paragraphs.

## 4. Geometry and Shapes
**CRITICAL RULE: NEVER use `border-radius` or `rounded-*` classes (except for perfect circles like status dots).**
All geometry uses angular cuts via `clip-path`.

- **`.clip-chamfer`**: Standard 10px cut on top-left and bottom-right.
- **`.clip-chamfer-sm`**: 4px cut for small badges.

### The Double Wrapper Border Technique
Because `clip-path` cuts off standard CSS `border`, you MUST use this nested pattern to create borders on chamfered elements:
```jsx
<div className="bg-[var(--color-steel)] clip-chamfer p-[1px] hover:bg-[var(--color-amber)] transition-colors group">
  <div className="bg-[var(--color-carbon)] clip-chamfer w-full h-full">
    Content goes here
  </div>
</div>
```
- The outer `div` determines the border color (`bg-[var(--color-steel)]`) and border thickness (`p-[1px]`).
- The inner `div` determines the background color.

## 5. Micro-interactions
- **Hover States**: Links and cards should transition borders/text to `--color-amber` or `--color-white`. Use Tailwind's `group` and `group-hover:` extensively.
- **Focus States**: Inputs use `focus-within:bg-[var(--color-amber)]` on their outer wrapper.
- **Depth**: Use inner shadows (`shadow-[inset_..._rgba(0,0,0,0.5)]`) to make inputs or specific panels feel mechanically recessed.
- **Z-Index/Clipping**: Be extremely careful with dropdowns/modals inside containers that have `clip-path`. `clip-path` acts as `overflow: hidden`. Place background clip-paths on absolute sibling layers (`z-[-1]`) behind `relative` content containers to allow modals to overlap without being cropped.
