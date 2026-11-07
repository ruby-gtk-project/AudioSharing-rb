# Accountability ensurance — AudioSharing-rb

## Scan run

```sh
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

against `lib/`, `exe/`, every `.md`, and the repo root. **Zero hits.**
No `PORTING.md`, `FINDINGS.md`, `COMPONENT_PARITY.md`, `TEST_PARITY.md` or
`TRANSLATION_PARITY.md` exists anywhere in the `ruby` tree — there is no
document for an excuse to live in. A manual grep confirms the negative
beyond the script's pattern list:

```sh
grep -rniE "TODO|FIXME|not implemented|for now|in a future|placeholder|stub\b" lib/ exe/ .reports/
```

The one hit, `.reports/component-inventory.md:41` — "the scaffold stub
`lib/audiosharing/application.rb` is gone" — is a factual past-tense
statement about a scaffold file that no longer exists, not an excuse for
anything missing now. Not rewritten.

## What this does, and does not, mean

**It does not mean the port has no gaps.** It means no gap in this port has
been *laundered into a decision* yet. The four other reports in this round
(`component-parity.md`, `test-parity.md`, `translation-parity.md`, plus the
`component-identification.md` addendum) name five real findings:

1. The repeat-activation guard upstream's `app.rs` has and `lib/main.rb`
   does not.
2. The entire `data/` packaging tree — desktop entry, metainfo, D-Bus
   service file, icons — never ported, with `Config::DESKTOP_ENTRY` and
   `Config::DBUS_SERVICE_NAME` sitting in `lib/config.rb` as dead
   constants nothing reads.
3. Four real translation gaps, all downstream of (2), plus one unmarked
   literal (`AboutDialog::DEVELOPER_NAME`).
4. The RTSP server's *success* path — a real sink, a real client
   connecting — has never been driven on any machine this audit can
   confirm; only the no-sink error path is proven live.
5. The 82-check drive gate covers 9 of 12 identified units; 3 are
   structurally outside what any check in the suite exercises (see above).

None of these appear anywhere in the port's source or docs as a sentence
excusing them — because, again, there is no sentence anywhere about them at
all. That is the finding this skill exists to make, stated plainly rather
than inferred: **the gaps are real and currently unrecorded, which is worse
than recorded-with-an-excuse only in the sense that a future reader has no
signpost to find them without re-running this audit.** They are recorded
now, in this round's five reports, with file:line citations in each.

## Checked specifically for the false-green failure mode

The task that commissioned this round named this explicitly: "a false green
in a report is the most serious finding you can make." The one place a
false green could have hidden is `.reports/component-inventory.md`'s row
10 ("config... **yes**"), which is accurate about `lib/config.rb` mirroring
upstream's *values* but says nothing about whether the *files* those values
describe (`.desktop`, `.service`, metainfo, icons) exist in the port. Re-read
closely, the row does not claim they do — but it also does not flag that
they don't, and a reader skimming "yes" rows could mistake coverage of the
config *module* for coverage of the config *unit*. That ambiguity is now
closed by `.reports/component-identification.md`'s addendum, which gives the
missing `data/` tree its own row rather than leaving it implicit inside a
"yes".

The runtime gate itself (`drive_ok: true`, 82/82 checks, 9 components) was
re-run live this session and reproduces exactly — it is not a stale or
fabricated figure. Its narrowness (3 of 12 units outside its reach) is
recorded in `.reports/test-parity.md` rather than left to make the 82/82 read
as more complete than it is.

## Rules check

- No construct from the pattern table was rewritten with a softened reason,
  because none was found to rewrite.
- No new excuse was introduced while writing this report — each gap above
  is stated as a behaviour owed (what the user does not get), with a
  file:line pointer, in its own ledger (`component-parity.md` /
  `translation-parity.md` / `test-parity.md`), not waved through here.
- This report does not cite any of the other four as authority for leaving
  a gap open; it cites them as where the gap is tracked.
