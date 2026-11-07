# Translation parity — AudioSharing-rb

| | |
|---|---|
| Upstream | `main` @ `a4b9350` |
| Port | `ruby` @ `165d81e` (re-verified this round — all 4 gaps below are unchanged; previous round was `c038da2`) |
| Domain | `audio-sharing` (upstream's `meson.project_name()`; port's `catalogue.rb` read it `unconfirmed` — see below) |
| Upstream messages | 18 |
| Ported (after hand-resolving scanner misses, see Step 2) | **14** |
| Real gaps | **4** |
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

## The 4 real gaps

| # | msgid | Where it lives upstream | Port site | State |
|---|---|---|---|---|
| 1 | `@NAME@` | `data/*.desktop.in.in:2`, `data/*.metainfo.xml.in.in` (a literal, untranslated-by-design placeholder — `po/de.po` carries `msgid "@NAME@"` / `msgstr "@NAME@"` verbatim) | — | **gap** |
| 2 | `Connect to the audio stream by scanning the QR code or copying the address` | `data/*.metainfo.xml.in.in` (screenshot `<caption>`) | — | **gap** |
| 3 | `Felix Häcker` | `data/*.metainfo.xml.in.in` (`<developer><name>`, translatable per AppStream ITS rules) | `AboutDialog::DEVELOPER_NAME` (`lib/about_dialog.rb:24`) exists but is a **bare literal, never passed through `_()`** | **gap** |
| 4 | `Gnome;GTK;audio;sharing;sound;` | `data/*.desktop.in.in:11` (`Keywords=`) | — | **gap** |

All four trace to the same root cause: **the port ships no `data/`
directory at all** — no `.desktop.in.in`, no `metainfo.xml.in.in`, no
`.service.in` (see `.reports/component-identification.md` and
`.reports/component-parity.md`). Gap #3 is additionally a pure
translation-marking miss independent of the missing file: even if
`lib/about_dialog.rb` is the right home for the developer's name (it is —
the about dialog shows it), the constant is never wrapped in `_()`.

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

`summary.parity: true` is **not** reached. 4 real gaps remain, all tied to
the missing `data/` tree. Closing them means: writing an actual
`data/de.haeckerfelix.AudioSharing.desktop.in.in` (and installing it),
writing the metainfo file with the screenshot caption, and wrapping
`AboutDialog::DEVELOPER_NAME` in `_()`. None of that is done by this audit;
this report records the gap, it does not close it.

**Re-verified this round, unchanged.** `grep -n 'DEVELOPER_NAME\|_('
lib/about_dialog.rb` run against `165d81e` still shows
`DEVELOPER_NAME = 'Felix Häcker'` as a bare constant, never passed through
`_()` (line 26), while `_()` wraps `SUMMARY`, each `DESCRIPTION` paragraph,
and `'translator-credits'` a few lines below it. `find . -iname
'*.desktop*' -o -iname '*metainfo*' -o -iname '*.svg'` (excluding `.git`)
still returns nothing anywhere in the `ruby` tree. All 4 gaps stand exactly
as last round left them; this round's commit (`165d81e`) touched only
`lib/main.rb`, not `po/`, `lib/gettext.rb`, `lib/about_dialog.rb`, or
`data/`.
