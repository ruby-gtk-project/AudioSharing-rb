# Test parity — AudioSharing-rb

| | |
|---|---|
| Upstream | `main` @ `a4b9350` |
| Port | `ruby` @ `165d81e` (re-verified this round; previous round was `c038da2`) |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 upstream-test gaps, but see "Narrowness" below — a behaviour with no upstream test can still have no port test either, and one now doesn't |
| Test command(s) | `nix develop --command xvfb-run -a ruby test/drive_window.rb` · `... test/check_qrcode.rb` · `... test/check_translations.rb` |

## Upstream has no test suite

Checked, not assumed:

```sh
grep -rn '#\[test\]\|#\[cfg(test)\]\|mod tests' /tmp/.../upstream-audiosharing/src/   # 0 hits
find /tmp/.../upstream-audiosharing -iname '*test*' -not -path '*/.git/*'            # 0 files
```

No `tests/` directory, no `[[test]]` in `Cargo.toml`, no `#[test]`/
`#[cfg(test)]`/`mod tests` anywhere in `src/`. Parity is **0/0 and is met
trivially — the port inherits no safety net.** Every check below was
written for the port and pins nothing upstream considered worth pinning.

## The suite was actually executed this session, not just read

Ran live, in the fork's dev shell, against a virtual display, this audit:

```
$ nix develop --command xvfb-run -a ruby test/drive_window.rb
...
82 of 82 checks passed
DRIVE OK

$ nix develop --command xvfb-run -a ruby test/check_qrcode.rb
...
QRCODE OK   (20 checks)

$ nix develop --command xvfb-run -a ruby test/check_translations.rb
...
TRANSLATIONS OK   (≈60 checks, incl. "50 of 51 catalogues carry translations")
```

The runtime gate this round (82 checks / 10 components / `drive_ok: true`)
matches `test/drive_window.rb` exactly — it is the drive script's own
count, re-run and reproduced here, not a figure taken on faith.
`test/check_qrcode.rb` and `test/check_translations.rb` were also re-run
live this round and both still pass (QRCODE OK, 20 checks; TRANSLATIONS OK).

**Round-2 update: `lib/main.rb` was changed since the last audit** (commit
`165d81e`, "Guard App#activate against a second activation restarting the
server") to add the `window_built?` guard the previous round's
`component-parity.md` flagged as missing. Reading the current source
confirms the fix matches upstream's shape: a second `activate` now only
presents the window and returns, it does not re-run `rtsp_server.start`.
**But no test exercises this.** `grep -n 'activate\|repeat' test/drive_window.rb`
turns up only the single `signal_connect('activate')` setup and the
`app.help_action.activate` / `app.about_action.activate` *action* calls —
nothing fires the application's `activate` signal a second time. The code
fix is real; the regression protection for it is not. If a future change
reintroduces the unconditional path, this suite would not catch it. That is
still a gap, just a different one than last round's (then: behaviour wrong
and unverified; now: behaviour right and still unverified).

**Narrowness of the gate, read against the component list:** the gate
reports "10 components" covered this round (component-identification.md's
addendum now counts 12 named units total, with the `data/` tree as its own
row). At least two units are still not exercised by any check in any of the
three test files:

1. **The `data/` packaging unit** — no check opens an installed `.desktop`
   file, loads the metainfo, or resolves the window icon from an icon
   theme, because none of those files exist to check (see
   `component-parity.md`). Unchanged from last round.
2. **A live audio sink.** `test/drive_window.rb` step 2 explicitly asserts
   `app.rtsp_server.device_name.nil?` and takes the *error* branch — this
   machine has no PulseAudio sink. The success path (`RtspServer#share`
   actually starting a `GstRtspServer::RTSPServer`, mounting the factory,
   and a client connecting to receive the notification) has **never been
   driven on any machine this audit can confirm.** `82/82` checks passing
   proves the error path and the UI around it; it does not prove the
   server itself ever serves audio. This is the single largest "a suite
   that passes is not the same as a suite that was executed against the
   real behaviour" risk in this port, and it is unresolved by this audit.
3. **The repeat-activation guard itself** (new this round, see above) —
   the behaviour exists now but is unverified, which this report counts
   as its own gap rather than folding it silently into "done."

## Extra

- `test/drive_window.rb` — 82 checks: window construction/geometry, the
  primary menu, the toast/clipboard round-trip, the three app actions and
  their accelerator, the about dialog's full field set, the error page,
  focus and the `<primary>q` accelerator closing the window.
- `test/check_qrcode.rb` — 20 checks: the QR matrix against a golden file,
  quiet zone, finder/timing patterns, and version-boundary capacity.
- `test/check_translations.rb` — catalogue completeness (50/51 non-empty),
  per-language message counts, and spot-translation checks for `de`,
  `fr`, `pt_BR` plus locale-fallback behaviour.

None of these corresponds to an upstream test; none claims to. They are
listed here, outside the 0/0 count, per the skill's own worked example for
an upstream suite of zero.
