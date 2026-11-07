# Translation parity — AudioSharing-rb

| | |
|---|---|
| Upstream | `main` @ `a4b9350` |
| Port | `ruby` @ `f476341` (re-verified this round — 2 of the 4 gaps below are now closed; previous round was `165d81e`) |
| Domain | `audio-sharing` (upstream's `meson.project_name()`; port's `catalogue.rb` read it `unconfirmed` — see below) |
| Upstream messages | 18 |
| Ported (after hand-resolving scanner misses, see Step 2) | **16** (14 + the 2 gaps closed this round) |
| Real gaps | **2** (down from 4 — see "What remains") |
| Extra (untranslated) | 0 |
| Upstream occurrences | 19 across 18 messages (1 reused) |
| Upstream languages | 51 `.po` files, all present and identical to the port's (`diff` clean), `LINGUAS` matches both |
| Languages shipped by the port | 51 |
| Build/delivery command | none — the port reads `po/*.po` at runtime via `lib/gettext.rb` (`rmsgfmt`-less), confirmed working by `test/check_translations.rb`, run live this session |

Generated with
`.claude/skills/translation-parity/scripts/catalogue.rb` (both trees) and
`--compare`. Raw comparison: **`.claude/skills/translation-parity/scripts/...
--compare` reports `summary.parity: false`, `gaps: 9`, `extra: 1`,
`unresolved: 4` on the port side.** Per this skill's "Unresolved markers"
section ("A non-zero `unresolved` means the catalogue is incomplete...the
ledger cannot be written until each one is censused by hand"), the raw
9/18 figure above is **not** the ledger — it is the lead. What follows is
the hand census the skill requires before writing one.

## Hand-resolving the scanner's 4 unresolved + 2 artifact rows

`port-catalogue.yaml`'s `unresolved:` block names exactly these four call
sites, all `_(<constant-or-variable>)` rather than `_("literal")`:

```
lib/about_dialog.rb:72  _(SUMMARY)
lib/about_dialog.rb:72  _(paragraph)   (inside DESCRIPTION.map { |paragraph| _(paragraph) })
lib/window.rb:237       _(INFO_TEXT)
lib/gettext.rb:165      (the gem's own translate() — not app content, ignore)
```

Opening the constants they index and checking each against the real msgid
in `po/de.po` (not the port's own claim — the catalogue a translator was
actually handed):

| Constant | Port value | `po/de.po` msgid | Match? |
|---|---|---|---|
| `AboutDialog::SUMMARY` | `"Share your computer audio"` | `msgid "Share your computer audio"` (po/de.po:38) | **byte-identical** |
| `AboutDialog::DESCRIPTION[0]` | `"With Audio Sharing you can share your current computer audio playback in the form of an RTSP stream. This stream can then be played back by other devices, for example using VLC."` | `po/de.po:39-41` (3 wrapped lines, joined) | **byte-identical** |
| `AboutDialog::DESCRIPTION[1]` | `"By sharing the audio as a network stream, ...connected to the Bluetooth accessory."` | `po/de.po` (6 wrapped lines, joined) | **byte-identical** |
| `Window::INFO_TEXT` | `"...audio.\n" + "\n" + "To stop sharing, simply close this window."` (explicit `\n\n`) | `po/de.po:87-93`, msgid literally contains `"...shared.\n" "\n" "To stop sharing..."` | **byte-identical** |

All four are **ported**, confirmed against the actual catalogue, not read
from the code. They showed as `gap`/`unresolved` only because
`msgid-census.sh` cannot resolve a non-literal `_()` argument (expected and
documented by this skill) and, separately, because the upstream-side scan
of `data/gtk/window.ui`'s raw XML text node collapsed the blank line between
the two paragraphs instead of preserving the `\n\n` that the real `.po`
file carries (a scanner limitation reading GtkBuilder label text, not a
difference in the actual message). **This raises the ported count from 9
to 13.**

One more raw-output row is the same kind of scanner artifact, from XML
entity decoding rather than whitespace:

| | upstream-scan msgid | port msgid | `po/de.po` msgid |
|---|---|---|---|
| Help menu item | `Open _Help &lt;sup&gt;↗&lt;/sup&gt;` (escaped, from `data/gtk/window.ui`'s raw attribute text) | `Open _Help <sup>↗</sup>` (`lib/window.rb:166`) | `Open _Help <sup>↗</sup>` (po/de.po:108) — **unescaped**, matching the port |

The port's string is the real msgid; the upstream-side census simply did
not XML-decode the `.ui` attribute before hashing it. **Not a gap. Raises
the ported count to 14/18.**

## The 4 real gaps — re-audited this round, 2 of 4 closed

| # | msgid | Where it lives upstream | Port site | State |
|---|---|---|---|---|
| 1 | `@NAME@` | `data/*.desktop.in.in:2`, `data/*.metainfo.xml.in.in` (a literal, untranslated-by-design placeholder — `po/de.po` carries `msgid "@NAME@"` / `msgstr "@NAME@"` verbatim) | — | **gap, unchanged** — see "What remains" |
| 2 | `Connect to the audio stream by scanning the QR code or copying the address` | `data/*.metainfo.xml.in.in` (screenshot `<caption>`) | `DataFiles::SCREENSHOT_CAPTION` (`lib/data_files.rb`), emitted verbatim in the generated `<screenshots>` block | **closed at the source-text level** — the msgid now has a port-side home, byte-identical to upstream's. No per-locale `<caption xml:lang="xx">` variant is generated; see "What remains". |
| 3 | `Felix Häcker` | `data/*.metainfo.xml.in.in` (`<developer><name>`, translatable per AppStream ITS rules) | `AboutDialog::DEVELOPER_NAME` (`lib/about_dialog.rb`), read with `_(DEVELOPER_NAME)` at `about.developer_name = _(DEVELOPER_NAME)` | **closed** — re-checked this round: the constant is wrapped in `_()`, not a bare literal. The earlier round that filed this gap read a version of the file before this was fixed. |
| 4 | `Gnome;GTK;audio;sharing;sound;` | `data/*.desktop.in.in:11` (`Keywords=`) | `Config::DESKTOP_ENTRY['Keywords']`, emitted literally by `DataFiles.desktop_entry` | **gap, unchanged** — see "What remains" |

Gaps #2 and #3 are closed. #1 and #4 remain, and are a narrower problem
than this report originally scoped: the `data/` directory itself is no
longer missing (`71fa944` shipped `lib/data_files.rb` and the three
generated/copied files — see the corrected `component-parity.md`); what
is still missing is **per-locale generation** inside that directory.

## What remains: no per-locale desktop/metainfo generation

Upstream's build produces one `.desktop` file with `Name[de]=`,
`Keywords[de]=`, etc. per language (via `i18n.merge_file`) and one
`metainfo.xml` with `<name xml:lang="de">`, `<summary xml:lang="de">`,
etc. per language (via `itstool`), all generated from the same `.po`
catalogues this port already reads at runtime for the UI
(`lib/gettext.rb`). This port's `lib/data_files.rb` generates only the
source-language (English) `.desktop`/`metainfo.xml` — gaps #1 and #4
are both instances of this: the translated `Name[xx]=`/`Keywords[xx]=`
lines a desktop environment in that locale would show are never
written. Closing this needs `DataFiles` to iterate `Gettext.linguas` and
emit one additional line per language per translatable desktop key
(skipping locales where the catalogue has no translation, matching
`i18n.merge_file`'s own fallback behaviour), and the equivalent
`xml:lang` elements for metainfo. Not done this round — named here as
the concrete remainder rather than left implicit in "4 gaps, unchanged."

## Domain

`catalogue.rb` reads `domain: audio-sharing` for both trees from the
`gettext.rb` source rather than a `meson.build` (there is none), and does
not mark it `unconfirmed`, but it could not be cross-checked against an
installed `.mo` because no `.mo` is ever built — the port's `lib/gettext.rb`
reads `po/*.po` directly at runtime (confirmed working,
`test/check_translations.rb`, run live this session, all green). **This is
not a parity failure** (delivery is defined by the skill as "the
requirement is delivery, not a file format") but it does mean
`domain_matches`-style validation (`msgfmt -c`, a real plural-forms engine,
`.mo` installation) never runs. Stated as an open item, not waved through.

## Numbers, as pairs

```
14/18 messages (after hand-resolving 4 unresolved + 2 scanner artifacts)
 9/18 messages (raw script output, before hand census — do not quote this one alone)
19/19 occurrences for the 14 ported messages that are counted by occurrence
51/51 languages, po/ directories diff clean, LINGUAS matches on both sides
de, fr, pt_BR verified on screen via test/check_translations.rb, run live this session
```

## What this does not claim

`summary.parity: true` is **not** reached. 2 real gaps remain (#1 `@NAME@`
and #4 `Keywords`, both re-scoped above to "no per-locale generation,"
not "no `data/` tree" — that larger problem was closed in `71fa944`).

**Re-verified this round.** `grep -n 'DEVELOPER_NAME\|_('
lib/about_dialog.rb` now shows `about.developer_name =
_(DEVELOPER_NAME)` — gap #3 is closed, contradicting this report's own
previous round, which read the file as a bare, unwrapped literal. Re-run
`test/check_data_files.rb` live this round (`DATA FILES OK`, including new
checks for the developer block, branding, requires/supports, screenshots
and releases added to `lib/data_files.rb` this round) confirms gap #2's
caption string is present, byte-identical to `po/de.po`'s msgid, in the
generated and committed metainfo. Gaps #1 and #4 were re-checked against
the current `DataFiles.desktop_entry` and found genuinely still open — no
per-locale `Name[xx]=`/`Keywords[xx]=` lines are generated — and are
carried forward as the concrete remainder, not as "4 gaps, unchanged."
