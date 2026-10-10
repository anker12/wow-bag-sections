# Changelog

What changed in each release of BagSections, written for players. Paste a release's
section into CurseForge's changelog box when uploading.

## [Unreleased]

### Added
- Quivers and ammo pouches get an Ammo section of their own at the bottom of the bags,
  like the reagent bag. Their slots are no longer mixed into Rest, and the free slot count
  leaves them out.
- At the bank, right-clicking a section in the bags offers "Move all to bank", and
  right-clicking a section in the bank offers "Move all to bags". Items move one at a time,
  onto stacks of the same item first. If some don't fit, a chat message says how many.
  The bags' Reagents has it too (right-click its header), and reagents moved to the bags
  go to the reagent bag first.

## [1.3.0] - 2026-10-06

### Added
- The bank window replaces Blizzard's at the banker ("Replace the default bank", on by
  default). It looks like Blizzard's bank: its border with the banker in the round corner,
  the stone background and the bank's bag slots along the bottom. Deposit and withdraw by
  right-click or drag and drop; search and sort work as in the bags. Away from the bank it
  shows your last visit, as before. Only the character bank is shown.
- The bank has its own layout and size settings: Bank layout, Bank columns (15 by default)
  and Bank scale.
- Every bank bag slot shows, bought or not (padlocked). Bags in bought slots can be swapped
  by clicking or dragging. "Buy slot" shows the price of the next slot (red if you can't
  afford it), and clicking a padlocked slot also offers to buy it.
- Hovering a bag button on the action bar glows that bag's slots in the bags, and hovering
  a bank bag slot glows that bag's slots in the bank: the slots to empty before swapping
  the bag.
- Bank sections, kept separately from the bag sections. The first visit to a banker offers
  to copy your bag sections; the bank's gear menu has New section and Copy sections from
  bags. The bank has an automatic Reagents section, on by default (Settings → Reagents
  section in the bank, for all your characters).
- Linked sections: a bag section and its bank copy share their items, so an item lands in
  the matching section when it moves between bags and bank. Sections with the same name
  are linked automatically. "New section" in either gear menu can make a linked copy of
  one from the other side.
- "Gather reagents from bags" setting (on by default): crafting reagents in your normal
  bags show in the Reagents section together with the reagent bag, as one block.
- Semi-compact spacing: two sliders in Settings for the space between rows of sections
  (4 by default) and between sections side by side (12 by default). The smallest settings
  still keep items clear of the section names below them.
- Live preview in Settings: while BagSections' settings page is open, the bags stay open
  above it (titled "Bags (preview)"), so you can see each change as you make it. Blizzard
  normally closes the bags while its Settings panel is open.

### Changed
- Semi-compact is now the default layout, for the bags and the bank. The old "Default"
  layout is now called "Stacked". Your current layout choice stays as it is.
- Settings are grouped under headings: Layout, Sections and items, Appearance, Text size,
  General and Profiles.
- The Quest Items section is on by default and applies to all your characters (it used to
  be per character), in the bags and the bank. Existing installs keep the setting of the
  first character you log in with. It's in Settings only, no longer in the gear menu.

### Fixed
- Section header lines no longer come and go (most visible in Semi-compact, and in the bank
  at its smaller scale): they're kept at least one screen pixel thick at any scale.

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
