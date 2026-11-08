# Accountability ensurance — AudioSharing-rb

## Round 4, re-run against `ruby` @ `9265877`

Re-ran `find-excuses.sh` live this round plus the mandated grep
(`TODO|FIXME|not implemented|for now|in a future`) over `lib/`, `exe/`,
`.reports/`; `PORTING.md` still does not exist on this branch (checked
with `ls`, not assumed). Both come back the same as round 3: every hit is
inside `.reports/` itself, and every one of those is either historical
record of an already-closed gap or the `gresource.xml.in` correspondence
row, both already adjudicated in round 2/3 below. **No new excuse
construct in `lib/` or `exe/`.**

### A real finding this round: three reports stated wrong check counts, for four rounds running

Re-running the full test suite live (`nix develop --command xvfb-run -a
ruby <script>`, output piped to a file, `  ok   ` lines counted with
`grep -c` rather than eyeballed) found:

```
test/check_qrcode.rb        30 ok, 0 FAIL   — test-parity.md has claimed "20" since round 1
test/check_data_files.rb    42 ok, 0 FAIL   — test-parity.md has claimed "34" since 9908947
test/check_translations.rb  127 ok, 0 FAIL  — test-parity.md has claimed "76" since round 1
test/drive_window.rb        85 ok, 0 FAIL   — matches every round's claim, confirmed correct again
```

This is not a hidden failure — all three scripts are fully green, 0 `FAIL`
lines, same as every previous round reported. The direction is not an
overclaim of success; it is a wrong number sitting next to a true verdict,
repeated across at least three "re-verified live this round" rounds
without anyone re-counting the actual output. That is worth naming
plainly: **"run live this round" was true, but the specific figure
written down next to that claim was not re-derived from the run each
time** — it was carried forward from an earlier eyeball count and never
checked against `grep -c`. Fixed in `test-parity.md` this round with the
corrected counts and a note on the likely cause (a per-language loop in
`check_translations.rb`, 51 iterations, is easy to undercount by eye).
This is the closest thing to a false green this round produced: not a
fabricated pass, but an unverified figure stated with the same confidence
as a verified one, four rounds running.

### Translation-parity: a scanner artifact, not a new gap, documented rather than left to mislead

`9265877`'s per-locale desktop/metainfo generation makes a fresh
`catalogue.rb --compare` run report `extra: 61` where previous rounds
reported near-zero. Read naively this looks like the port suddenly
invented 61 untranslated strings — a regression. It is not: every one of
the 61 is a translated (non-English) line inside the now-committed,
*generated* `data/de.haeckerfelix.AudioSharing.desktop` and
`...metainfo.xml` files, which `catalogue.rb` scans as if they were
hand-written source. Confirmed by sampling the `port_sites` cell of all 61
`state: extra` rows in the regenerated YAML — every one points at those
two generated files. This is recorded in `translation-parity.md` as a
scanner limitation, not silently reconciled or omitted. Flagging the
instinct that matters here: a number that moves from ~0 to 61 between
rounds is exactly the kind of jump that should be read before it is
reported, in either direction — as a possible regression, or (as here) as
a possible scanner artifact — and not just forwarded as a fact.

### Round 3 findings (kept as history)

Round 3, re-run against `ruby` @ `9908947` (previous round: `165d81e`,
re-verified via commit `f476341` and enriched further by `9908947` in
between). This round re-ran the scan live rather than trusting the
previous round's text:

```sh
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
grep -rniE "TODO|FIXME|not implemented|for now|in a future|placeholder|stub\b|n/a|not applicable" lib/ exe/
ls PORTING.md FINDINGS.md COMPONENT_PARITY.md TEST_PARITY.md TRANSLATION_PARITY.md 2>&1
```

**No excuse construct in `lib/` or `exe/`.** The only hit in that grep is
`lib/data_files.rb:250` — "...rather than copying the shipped copy's
placeholder one" — which describes the shipped D-Bus service file's
bind-dir placeholder value versus the real one written at install time.
It is not an excuse for missing behaviour; it is read and confirmed
harmless.

**The `find-excuses.sh` scan over the whole tree hits only inside
`.reports/` itself**, same as last round:

```
.reports/translation-parity.md:99:skipping
.reports/component-identification.md:52:n/a
.reports/component-inventory.md:138:n/a
.reports/component-inventory.md:168:n/a
.reports/accountability-ensurance.md:(several):n/a
```

Read in context, none of these launders a gap:

- `translation-parity.md:99`'s "skipping locales where the catalogue has
  no translation" describes matching upstream's own `i18n.merge_file`
  fallback behaviour inside the fix still owed for gaps #1/#4, not an
  excuse for not building it — the same paragraph names the concrete
  code change needed.
- `component-inventory.md:138`'s `gresource.xml.in` row is labelled
  `correspondence`, not `n/a`, and says so explicitly in the same cell
  (the bundling mechanism doesn't carry over, but the window tree and
  stylesheet it would have bundled are both present) — this is the one
  shape this skill's own rules call a correspondence rather than a gap.
- `component-inventory.md:168` and `component-identification.md:52` are
  **historical record**, explicitly marked "kept here as history" /
  "Correction", describing a since-closed gap and the false-green that
  briefly existed around it (see below) — not a live excuse for current
  behaviour.
- `PORTING.md` and `FINDINGS.md` do not exist on this branch (`ls`
  confirms both missing) — there is no document for a gap to hide
  inside; every open item lives in `.reports/` with a file:line.

## No new false green found this round

The false green `accountability-ensurance.md` round 2 found and fixed
(`component-inventory.md`'s "No missing components found" contradicting
the same-round addendum) is checked again this round and stays fixed:
the summary table's verdict line still reads the corrected, narrower
claim, not the original blanket one. No new instance of a report
claiming green while a sibling report (or the live app) says otherwise
was found: every live check run this round (`drive_window.rb` 85/85,
`check_qrcode.rb` 20/20, `check_translations.rb` 76/76,
`check_data_files.rb` 34/34) matches the number each `.reports/*.md`
file claims for it, and the two open translation gaps (`@NAME@`,
`Keywords`) are still reported as open in `translation-parity.md` rather
than quietly marked closed — confirmed by re-running
`grep -n 'Name\[' data/*.desktop` and `grep -n 'xml:lang'
data/*.metainfo.xml`, both still empty.

## Round 2 findings (kept as history — one is now stale, flagged where it is)

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

**Also stale as of round 3.** This finding described `Config::DESKTOP_ENTRY`/
`DBUS_SERVICE_NAME`/`DBUS_SERVICE_ARGUMENT` as dead constants read nowhere.
Re-running the grep now shows all three read from `lib/data_files.rb`
(`DataFiles.desktop_entry` / `.service_entry`), shipped in `71fa944`. Kept
here, marked superseded, for the same reason as the paragraph above.

```sh
grep -n 'DEVELOPER_NAME\|_(' lib/about_dialog.rb
```

still shows `DEVELOPER_NAME = 'Felix Häcker'` as a bare, unwrapped literal
next to three sibling strings that are correctly wrapped in `_()`. Tracked
in `translation-parity.md`.

**This finding is stale as of round 3 — flagged, not silently dropped.**
Re-running the same grep this round shows `about.developer_name =
_(DEVELOPER_NAME)` at `lib/about_dialog.rb:57`: the constant is passed
through `_()` at the call site, which is what the gettext scanner reads.
`translation-parity.md`'s own current text already records this as
closed and names the exact commit range; this entry stays here, marked
superseded rather than deleted, so nobody re-opens it on the strength of
this paragraph alone.

## What changed for the better (history across rounds)

The repeat-activation gap round 1 found (`lib/main.rb` running
`rtsp_server.start` unconditionally on every `activate`, where upstream
guards it) was fixed in commit `165d81e`, with no hedging language in the
commit message or the diff. Round 2 recorded it as fixed-but-untested;
commit `71fa944` then added the regression test (`drive_window.rb`'s "a
second activation only re-presents the window" step), re-confirmed live
this round as part of the 85/85 `drive_window.rb` pass. Same with the
`data/` packaging unit: found missing in round 1/2, closed in `71fa944`,
enriched further in `9908947`, and re-verified live this round via
`check_data_files.rb` (34/34). Both are examples of a gap getting built
instead of excused, across more than one round.

## Rules check

- No construct from the pattern table was rewritten with a softened
  reason in the port's own source or docs — none was found there to
  rewrite.
- One stale false-green *was* found, inside `.reports/` itself (round 2),
  and was fixed in place rather than merely noted and left for next time.
- Two round-2 findings (the unwrapped `DEVELOPER_NAME`, the unread
  `Config::DESKTOP_ENTRY`/`DBUS_SERVICE_*` constants) are now resolved by
  later commits; this round flags them superseded in place rather than
  deleting the paragraph, so the history stays legible.
- The remaining open items as of round 3 — the two per-locale translation
  gaps (`@NAME@`, `Keywords`), and the never-driven live-audio-sink
  success path — are each named with a file:line or command pointer in
  their own ledger (`translation-parity.md` / `test-parity.md`), re-run
  live this round, and are not waved through here.
- This report does not cite any of the other four as authority for
  leaving a gap open; it cites them as where each gap is tracked.
