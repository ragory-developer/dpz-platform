---
name: dpz-border-fixer
description: DPZ border, high-contrast, and clip-path styling fixer skill for Dhaka Parts Zone.
---

# DPZ Border Fixer Skill

This skill provides mandatory rules and patterns for enforcing high-contrast, crisp borders, and fixing `clip-path` border clipping across dark carbon/gunmetal backgrounds in Dhaka Parts Zone (DPZ).

## 1. Border High-Contrast Rules
On dark background surfaces (`#0C0E12`, `#1A1D24`), default 1px thin low-contrast borders become invisible.

- **Inputs & Fields**: Always use `border-2 border-slate-600` (`#454F5B`).
- **Focus Rings**: Always use `focus-within:border-[var(--color-amber)]` with glow shadow `box-shadow: 0 0 10px rgba(255,159,0,0.4)`.
- **Card Containers**: Use 2px gradient border wrappers (`from-slate-600 via-slate-700 to-slate-800 p-[2px]`).
- **Dividers & Grids**: Use `border-b-2 border-slate-700/80` or `border-r-2 border-slate-700/80`.

## 2. Double Wrapper Chamfer Technique
Standard CSS `border` is clipped away by CSS `clip-path`. To render sharp borders on chamfered elements:

```tsx
<div className="bg-slate-700 clip-chamfer p-[2px] hover:bg-[var(--color-amber)] transition-colors group">
  <div className="bg-[var(--color-carbon)] clip-chamfer w-full h-full p-6">
    {/* Card Content */}
  </div>
</div>
```

## 3. Product Overview & Modal Images
- Do **NOT** use circular (`rounded-full`) cropped containers for product images.
- Always use square/chamfered containers (`border-2 border-slate-700 clip-chamfer p-4`) with `object-contain` so the full product image is rendered clearly without clipping.
