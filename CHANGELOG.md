# Changelog

What changed in each release of BagSections, written for players. Paste a release's
section into CurseForge's changelog box when uploading.

## [Unreleased]

## [1.3.0] - 2026-10-04

### Added
- Semi-compact section spacing: a slider in Options > AddOns > BagSections for the space
  between sections in the Semi-compact layout. The default looks the same as before, and
  the smallest setting still keeps items clear of the section names below them.

## [1.2.1] - 2026-10-04

### Fixed
- The bank window showed a Lua error ("Couldn't find inherited node 'ItemButtonTemplate'")
  and only the "visit a bank" hint instead of your bank.

## [1.2.0] - 2026-10-04

### Added
- View your bank from anywhere: right-click the "Bags" title, or type `/bs bank`. The
  bank is remembered on every visit, your character's bank per character and the account
  bank for all characters. Shows each bank tab, free slots, and when it was last updated.

## [1.1.1] - 2026-10-04

### Fixed
- "BagSections has been blocked from an action" when right-clicking consumables, and a
  Lua error from Blizzard's bag code when pressing B. BagSections no longer runs any of
  Blizzard's bag code itself; closing the window with its X now leaves Blizzard's hidden
  bags alone, and B still opens the bags again in one press.

## [1.1.0] - 2026-10-04

### Added
- Tracked currencies show at the bottom of the bags, next to your gold. Tick "Show on
  Backpack" for a currency in the Currency tab to track it. If they don't fit next to the
  gold, they move to their own line above it instead of overlapping.
- Text size settings for section names, gold and currencies, and the free slots count, in
  Options > AddOns > BagSections.

## [1.0.0] - 2026-10-04

First public release.

### Added
- One combined bag window with your own named sections. Each section sorts on its own,
  and everything else goes into Rest.
- Drag and drop items between sections and Rest, with blue highlights where you can drop.
- Match an item by "this exact item" or "every item of this kind", per item or for all gear.
- Optional automatic Quest Items section.
- Three layouts: Default, Semi-compact (sections side by side, rows you arrange by
  dragging) and Compact (one gap-free grid with coloured outlines).
- Rest position setting: new sections go above or below Rest.
- Profiles to save, load and share your section setup with copy-and-paste codes.
- Appearance settings: Dark or Blizzard background, opacity, Blizzard border, outline
  opacity and section name tooltips.
- Collapsible sections, search, and gold and free slots in the footer.
