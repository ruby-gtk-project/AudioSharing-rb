# Component parity — AudioSharing-rb

| | |
|---|---|
| Upstream | `main` @ `a4b9350` |
| Port | `ruby` @ `165d81e` (re-verified this round; previous round was `c038da2`) |
| Units with full parity | 10 / 12 (the application unit's repeat-activation gap was closed this round; see below) |

Scan evidence: `component-scan.sh` run against both trees
(`.claude/skills/component-identification/scripts/component-scan.sh`),
44 upstream rows / 41 port rows, plus manual reading of every mapped file
pair (the scan alone is a lead, never a verdict — Step 1 of this skill).

## Unit: application — `src/main.rs` + `src/app.rs` → `lib/main.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| `Gtk.UriLauncher` / `app.help` | 1 | 1 (`lib/main.rb:#open_help`) | parity |
| `Gio.Notification` plumbing | via `app.rs` | `lib/rtsp_server.rb` | parity (correspondence: the port splits this into its own file, named in the base inventory) |
| 3 actions (`help`, `about`, `quit`) | 3 | 3 | parity |
| `<primary>q` accel on `app.quit` | 1 | 1 | parity |
| `configure_process` (app name, icon name, 2 PulseAudio env vars) | yes | yes (`lib/main.rb#configure_process`) | parity |

**Fixed this round — repeat-activation guard.** Last round found upstream's
`activate` checking `self.window.get()` and, on a second activation,
presenting the existing window and returning before reaching
`setup_server` (`src/app.rs:40-47`), while the port's `App#build` ran
`actions; main_window.present; rtsp_server.start` unconditionally. Commit
`165d81e` ("Guard App#activate against a second activation restarting the
server") adds `App#activate` with a `window_built?` check
(`lib/main.rb`): a second activation now only presents the window, matching
upstream's single-setup behaviour. Read live this session — the fix is
correct and matches upstream's shape. **parity, as of this commit** — but
see `test-parity.md`: no check in the suite fires the application's
`activate` signal twice, so this fix has no regression test. Recorded there
as a live gap, not erased here.

## Unit: window — `src/ui/window.rs` + `data/gtk/window.ui` → `lib/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `audio-sharing-window` | — | — | parity |
| `Gtk.WindowHandle` | 1 | 1 | — | — | — | parity |
| `Adw.ToolbarView` / `Adw.HeaderBar` | 1/1 | 1/1 | — | — | — | parity |
| `Gtk.MenuButton` (appmenu) | 1 | 1 | ✓ `circular` | — | ✓ `Menu` | parity |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `Gtk.ScrolledWindow` / `Adw.Clamp` (500) | 1/1 | 1/1 | — | — | — | parity |
| `Gtk.Stack` (2 pages) | 1 | 1 | — | — | — | parity |
| `Gtk.Picture` (qrcode, 200×200) | 1 | 1 | ✓ `card` | — | — | parity |
| `Gtk.Label` (address) | 1 | 1 | ✓ `title-3` | — | — | parity |
| `Gtk.Button` (copy) | 1 | 1 | ✓ `pill` | ✓ `clicked` → clipboard + toast | ✓ `_Copy to Clipboard` | parity |
| `Gtk.Separator` | 1 | 1 | — | — | — | parity |
| `Gtk.Label` (info paragraph) | 1 | 1 | ✓ `caption` | — | ✓ (byte-identical, verified below) | parity |
| `Adw.StatusPage` (error) | 1 | 1 | — | — | ✓ `Unable to Share Audio` | parity |
| `Adw.Toast` (copy confirmation, 2s) | 1 | 1 | — | — | ✓ `Copied address to clipboard` | parity |

Menu (`primary_menu`): 2 sections, 2 items, `app.help` carrying
`use-markup` and the `<sup>↗</sup>` label, `app.about` — both present,
byte-identical labels (verified against `po/de.po`, see translation-parity).

Driven (`test/drive_window.rb`, run live this session, 82/82 checks green):
window geometry, drag handle, clamp width, stack page count, menu structure,
popover open/close, clipboard set + toast raised, paste round-trip, `app.*`
actions present/enabled with the accelerator, `<primary>q` closing the
window. **Behaviour confirmed, not just connected.**

Unit: **parity.**

## Unit: about dialog — `src/ui/about_dialog.rs` → `lib/about_dialog.rb`

All fields upstream's free function sets by hand plus the ones
`from_appdata` would have pulled from the metainfo are present and, per the
live drive run, correct at runtime: application name/icon, developer name,
2 developers, 1 designer, translator-credits, version (including the
`-<vcs_tag> (devel)` conditional — `Config.display_version`), website,
issue tracker, Donate link, license type, and the summary+description
comments text. **Minor note, not scored as a gap:** upstream's metainfo
carries two licenses — `metadata_license: CC0-1.0` and
`project_license: GPL-3.0-or-later` — and `Adw.AboutDialog` only has one
`license-type` property, which the port sets to `Gtk::License::GPL_3_0`.
`from_appdata` would have made the same reduction; this is a correspondence,
not a port-introduced loss.

Unit: **parity.**

## Unit: QR code model — `src/qrcode.rs` → `lib/qrcode.rb`

Properties/shape (`items`, `width`, `height`) match; encoding substituted
with `rqrcode_core` per the recorded correspondence. `test/check_qrcode.rb`
(run live, 20/20 green) checks the matrix against a golden file, quiet zone,
finder/timing patterns, and the version-11 capacity boundary. Unit: **parity.**

## Unit: QR code paintable — `src/ui/qrcode_paintable.rs` → `lib/qrcode_paintable.rb`

Cairo→`Gdk::Texture` substitution recorded and correct: module grid, 1-module
padding on top of the matrix's own quiet zone, white background + black
modules. Driven checks (`test/drive_window.rb` lines 213-243) assert on the
empty-code fallback and the address-code render, including texture size
scaling with QR version. Unit: **parity.**

## Unit: RTSP server — `src/app.rs` (server half) → `lib/rtsp_server.rb`

`find_device_name`/`device_name`, `get_ip_addr`/`ip_address`, `setup_server`/
`share`, the exact launch pipeline string, the `audio-sharing-playback`
notification id and its two translated strings — all present and, on this
headless machine with no PulseAudio sink, behave exactly as upstream would
(`No audio sink found`, shown on the error page). The repeat-activation
guard (above) now also protects this unit from a second `share` call. Unit:
**parity** for the single-activation, no-sink path, confirmed live. The
success path — a real sink, `GstRtspServer::RTSPServer` actually serving, a
client connecting — has never been driven on any machine this audit can
confirm (see `test-parity.md`); that absence of evidence is scored there,
not silently assumed as parity here.

## Unit: data/ packaging — `data/*.in.in`, `data/icons/**`, `data/gtk/style.css` → **nothing**

See `.reports/component-identification.md` addendum. No `.desktop` file, no
AppStream `metainfo.xml`, no D-Bus `.service` file, and no icon file (`.svg`,
scalable or symbolic) exists anywhere in the `ruby` tree. Concretely:

- `Gtk::Window.set_default_icon_name(Config::APP_ID)`
  (`lib/main.rb#configure_process`) names an icon that is never installed,
  so the window/taskbar icon resolves to the system's missing-icon
  placeholder rather than Audio Sharing's branded icon.
- `Config::DESKTOP_ENTRY`, `Config::DBUS_SERVICE_NAME` and
  `Config::DBUS_SERVICE_ARGUMENT` (`lib/config.rb:40-57`) are built and
  never read by anything — dead constants standing in for a file that was
  never written. Nothing in the port can be D-Bus-activated, launched from
  an app grid, or found by `gnome-software`/`flatpak`.
- The screenshot caption msgid ("Connect to the audio stream by scanning
  the QR code or copying the address") and the metainfo developer name
  (translatable `Felix Häcker`) have no port-side home at all — tracked
  again in `translation-parity.md`.

**gap.**

## Rules check

- No app-wide totals substituted for per-unit comparison above.
- Every extra (none found beyond house-style restructuring already recorded
  as correspondences in the base inventory) is accounted for.
- The repeat-activation and missing-`data/`-unit gaps are both named with
  file:line and are not excused anywhere in this document.
