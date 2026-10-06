# Changelog

What changed in each release of BagSections, written for players. Paste a release's
section into CurseForge's changelog box when uploading.

## [Unreleased]

### Changed
- The bank window looks more like Blizzard's: its border with the round portrait corner
  (the banker, or a bank icon away from the bank).
- Every bank bag slot shows along the bottom, bought or not (padlocked). Bags in bought
  slots can be swapped by clicking or dragging, as in Blizzard's bank.
- Hovering a bag button on the action bar glows that bag's slots in the bags, and hovering
  a bank bag slot glows that bag's slots in the bank: the slots to empty before swapping
  the bag, as Blizzard's bags and bank show them.
- "Buy tab" is now "Buy slot", with the price of the next slot next to it (red if you can't
  afford it). Clicking a padlocked slot also offers to buy it. Buying goes through
  Blizzard's own purchase button and dialog, so it's no longer blocked.
- The Quest Items section setting now covers the bank too: turning it on or off changes
  both the bags and the bank. The bank's gear menu has the switch too.

### Added
- The bank window replaces Blizzard's at the banker ("Replace the default bank", on by
  default): Blizzard's look (stone background, the bank's bag slots at the bottom, buy a
  tab), its own layout and size settings (Bank layout, Bank columns: 15 by default, Bank
  scale), deposit and withdraw by
  right-click, drag and drop, search and sort. Away from the bank it shows the last visit,
  as before. Only the character bank is shown.
- Bank sections, kept separately from the bag sections. The first visit to a banker offers
  to copy your bag sections and add an automatic Reagents section; the bank's gear menu has
  New section, Copy sections from bags and the Reagents section switch.
- Linked sections: a bag section and its bank copy share their items, so an item lands in
  the matching section when it moves between bags and bank. Sections with the same name
  are linked automatically. "New section" in either gear menu can make a linked copy of
  one from the other side.
- "Gather reagents from bags" setting (off by default): crafting reagents in your normal
  bags show in the Reagents section together with the reagent bag, as one block.

### Changed
- Settings are grouped under headings: Layout, Sections and items, Appearance, Text size,
  General and Profiles.
- The Quest Items section is on by default, and the setting now applies to all your
  characters (it used to be per character). Existing installs keep the setting of the
  first character you log in with.

### Fixed
- Section header lines no longer come and go (most visible in Semi-compact, and in the bank
  at its smaller scale): they're kept at least one screen pixel thick at any scale.

## [1.3.0] - 2026-10-04

### Added
- Semi-compact spacing: two sliders in Options > AddOns > BagSections, for the space
  between rows of sections and between sections side by side. The defaults look the same
  as before, and the smallest settings still keep items clear of the section names below
  them.
- Live preview in Settings: while BagSections' settings page is open, the bags stay open
  above it (titled "Bags (preview)"), so you can see each change as you make it. Blizzard
  normally closes the bags while its Settings panel is open.

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
