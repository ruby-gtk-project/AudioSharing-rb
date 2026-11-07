# Test parity — AudioSharing-rb

| | |
|---|---|
| Upstream | `main` @ `a4b9350` |
| Port | `ruby` @ `9908947` (re-verified this round; previous round was `f476341`) |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 upstream-test gaps; see "Narrowness" below for the one real coverage gap that remains (the live-sink success path) |
| Test command(s) | `nix develop --command xvfb-run -a ruby test/drive_window.rb` · `... test/check_qrcode.rb` · `... test/check_translations.rb` · `... test/check_data_files.rb` |

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
85 of 85 checks passed
DRIVE OK

$ nix develop --command xvfb-run -a ruby test/check_qrcode.rb
...
QRCODE OK   (20 checks)

$ nix develop --command xvfb-run -a ruby test/check_translations.rb
...
TRANSLATIONS OK   (76 checks)

$ nix develop --command xvfb-run -a ruby test/check_data_files.rb
...
DATA FILES OK   (34 checks, up from 11 — `9908947` added the developer/
branding/hardware/screenshot/release assertions)
```

The runtime gate this round (85 checks in `test/drive_window.rb`, unchanged
since `f476341`) matches the drive script's own count, re-run and
reproduced here, not a figure taken on faith. The other three scripts were
also re-run live this round; `check_data_files.rb` grew from 11 to 34
checks in `9908947` and all 34 pass.

**Closed — the repeat-activation guard now has a regression test.**
Commit `165d81e` ("Guard App#activate against a second activation
restarting the server") added the `window_built?` guard; the previous
round of this report flagged it as fixed but unverified. Commit `71fa944`
closed that: `test/drive_window.rb`'s "a second activation only
re-presents the window" step (re-read this round, lines 346-358) stubs
`RtspServer#start` to count calls, invokes `App#activate` a second time
directly (documented in-file as the deliberate way to exercise the guard
without re-entering the harness's own `activate` handler), and asserts
`app.main_window.equal?(window_before)`, the window is still visible, and
`starts.zero?`. All three assertions are part of the 85 checks that just
passed live. **No longer a gap.**

**Closed — the `data/` packaging unit now has its own check file.**
`test/check_data_files.rb` (new in `71fa944`) opens the committed
`.desktop` and metainfo files and asserts on the app id, summary, both
description paragraphs, developer name and homepage link; re-generates
both with `DataFiles.generate!` and asserts the result is byte-identical
to what is committed; and asserts all three icon files exist on disk.
This is a port-side check, not an upstream one (upstream has no test
suite at all, see above), and it does not open an *installed* `.desktop`
file through a desktop-file-validator or resolve the icon through
GTK's icon theme at runtime — so "the generated files are correct" is
proven, "a desktop environment would actually find and use them" is not.
That narrower claim is the gap recorded below, not the broader one this
report used to carry.

**Narrowness of the gate, read against the component list:** one real gap
remains, not two:

1. **A live audio sink.** `test/drive_window.rb` step 2 explicitly asserts
   `app.rtsp_server.device_name.nil?` and takes the *error* branch — this
   machine has no PulseAudio sink. The success path (`RtspServer#share`
   actually starting a `GstRtspServer::RTSPServer`, mounting the factory,
   and a client connecting to receive the notification) has **never been
   driven on any machine this audit can confirm.** `85/85` checks passing
   proves the error path and the UI around it; it does not prove the
   server itself ever serves audio. This is the single largest "a suite
   that passes is not the same as a suite that was executed against the
   real behaviour" risk in this port, and it is unresolved by this audit.
   Closing it needs either a machine with a real or virtual (e.g.
   `pulseaudio --start` plus a null sink) audio sink wired into CI, or an
   `RtspServer` test that fakes `Gst::DeviceMonitor` to return a sink and
   drives a real RTSP client against `rtsp.attach`'s server — neither of
   which exists yet.

## Extra

- `test/drive_window.rb` — 85 checks: window construction/geometry, the
  primary menu, the toast/clipboard round-trip, the three app actions and
  their accelerator, the repeat-activation guard, the about dialog's full
  field set, the error page, focus and the `<primary>q` accelerator
  closing the window.
- `test/check_qrcode.rb` — 20 checks: the QR matrix against a golden file,
  quiet zone, finder/timing patterns, and version-boundary capacity.
- `test/check_translations.rb` — catalogue completeness (50/51 non-empty),
  per-language message counts, and spot-translation checks for `de`,
  `fr`, `pt_BR` plus locale-fallback behaviour.
- `test/check_data_files.rb` — 34 checks: the generated desktop entry and
  metainfo (including the developer id, branding colours, hardware
  requirements, screenshot caption and full release history added in
  `9908947`) carry the right content and regenerate byte-for-byte, and
  all three icon files are present.

None of these corresponds to an upstream test; none claims to. They are
listed here, outside the 0/0 count, per the skill's own worked example for
an upstream suite of zero.
