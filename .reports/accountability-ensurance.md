# Accountability ensurance — AudioSharing-rb

Round 2, re-run against `ruby` @ `165d81e` (previous round: `c038da2`).

## Scan run

```sh
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

against `lib/`, `exe/`, `.reports/`, and the repo root. Also:

```sh
grep -rniE "TODO|FIXME|not implemented|for now|in a future|placeholder|stub\b" lib/ exe/ .reports/ PORTING.md
```

(`PORTING.md` does not exist on `ruby` — checked, not assumed:
`ls PORTING.md` → "No such file or directory".)

**No `TODO`/`FIXME`/`not implemented`/`for now`/`in a future` hits anywhere
in `lib/`, `exe/`, or `.reports/`.** The grep's only hits are inside the
`.reports/` prose describing *upstream's* placeholder-by-design string
(`@NAME@`, a literal gettext never-translated marker — `translation-parity.md`
line ~75) and the skill's own pattern-table header text quoted inside
`accountability-ensurance.md` itself. Neither is an excuse for a gap in
this port; both are reporting on upstream's or the skill's own text.

## The most serious finding this round: a false green that survived one full round uncorrected

The task commissioning this round named this explicitly: "a false green in
a report is the most serious finding you can make." This round found one,
and it was not in `lib/` or `exe/` — it was already sitting in `.reports/`
from the *previous* round, where `find-excuses.sh`'s own pattern table
(which flags `n/a` as a suspect construct — "asserts the behaviour cannot
exist here") caught it on a second pass:

`.reports/component-inventory.md`'s original summary table carried:

```
| `data/de.haeckerfelix.AudioSharing.gresource.xml.in` | n/a — port has no
  GResource bundle... | — | n/a |
| `data/icons/**` | n/a — app icon, not a UI component; not covered by this
  inventory | — | n/a |
```

followed by: **"No missing components found."**

But the *same previous round*, in the *same `.reports/` folder*, wrote
`.reports/component-identification.md`'s addendum, which found and named
exactly those icon files (plus the desktop entry, metainfo, and D-Bus
service file) as a missing unit — three `.svg` rows, each marked `**none**`.
The addendum's correction was never carried back into
`component-inventory.md`'s own summary line. A reader who opened only
`component-inventory.md` — the base document, read first, and the one a
"yes"/"present" skim is most likely to stop at — saw a clean "No missing
components found" verdict that the very next document in the same folder
contradicted. That is a false green: not a lie anyone told on purpose, but
a correction that was made once, in one place, and never propagated to the
document whose verdict it invalidated.

**Fixed this round, not just flagged.** `component-inventory.md`'s summary
table and verdict line are rewritten in place (see the "Correction" note
now in that file) to mark `data/icons/**` and the 3 `data/*.in(.in)` files
as missing rather than `n/a`, and to replace "No missing components found"
with the accurate, narrower claim (every *widget/action/accelerator*-contributing
file is ported; the `data/` packaging tree is not). The `gresource.xml.in`
row is relabeled `correspondence` (the bundling mechanism legitimately
doesn't carry over) rather than `n/a`, which the pattern table treats as
presumptively suspect and which this one, read carefully, earns — it
asserts a mechanism doesn't carry over while the behaviour (the window's
own widget tree) does, which is the correspondence shape, not the excuse
shape. This is recorded here as what happened to it, not left for a future
round to re-discover.

## Other findings this round, carried from the port source itself

```sh
grep -n 'DESKTOP_ENTRY\|DBUS_SERVICE' lib/*.rb exe/*
```

still shows `Config::DESKTOP_ENTRY`, `Config::DBUS_SERVICE_NAME`, and
`Config::DBUS_SERVICE_ARGUMENT` built in `lib/config.rb` and read nowhere
else — dead constants standing in for files that don't exist. Not an
excuse (nothing in the source comments on why), but a live gap, tracked in
`component-parity.md` and `translation-parity.md`.

```sh
grep -n 'DEVELOPER_NAME\|_(' lib/about_dialog.rb
```

still shows `DEVELOPER_NAME = 'Felix Häcker'` as a bare, unwrapped literal
next to three sibling strings that are correctly wrapped in `_()`. Tracked
in `translation-parity.md`.

## What changed for the better this round

The repeat-activation gap the previous round found (`lib/main.rb` running
`rtsp_server.start` unconditionally on every `activate`, where upstream
guards it) **was fixed**, in commit `165d81e`, with no hedging language in
the commit message or the diff — it names the behaviour it was missing and
closes it. That is the opposite of laundering a gap into a decision: it is
a gap that got built instead of excused. It is not yet *tested* (see
`test-parity.md`), which this round records as its own open item rather
than crediting the fix with more certainty than a live regression test
would give it.

## Rules check

- No construct from the pattern table was rewritten with a softened
  reason in the port's own source or docs — none was found there to
  rewrite.
- One stale false-green *was* found, inside `.reports/` itself, and is
  fixed above rather than merely noted and left for next time.
- Every other open item (data/ tree, 4 translation gaps, untested
  repeat-activation guard, unverified audio-sink success path) is named
  with a file:line or command pointer in its own ledger
  (`component-parity.md` / `translation-parity.md` / `test-parity.md`),
  not waved through here.
- This report does not cite any of the other four as authority for
  leaving a gap open; it cites them as where each gap is tracked, and
  corrects the one document whose own verdict was wrong.
