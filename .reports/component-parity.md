# Component parity — AudioSharing-rb

| | |
|---|---|
| Upstream | `main` @ `a4b9350` |
| Port | `ruby` @ `c038da2` |
| Units with full parity | 9 / 12 |

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

**Gap — repeat-activation guard not ported.** Upstream's `activate` checks
`self.window.get()`; on a second activation it **presents the existing
window and returns before reaching `setup_server`** (`src/app.rs:40-47`,
"If the window already exists ... return"). The port's `App#build`
(`lib/main.rb:29-35`) runs `actions; main_window.present; rtsp_server.start`
unconditionally on every `activate` signal. `actions` and `main_window` are
memoized so they no-op safely, but `rtsp_server.start` is not idempotent in
the same way: `RtspServer#share` (`lib/rtsp_server.rb:128-133`) calls
`rtsp.mount_points.add_factory(MOUNT_POINT, media_factory)` and
`rtsp.attach(...)` again on every call, against the same memoized `@server`.
Upstream never reaches `setup_server` twice in one process; the port does,
on every repeat activation (a second `gapplication-service`-style invocation
reaching the same running instance, which the desktop file's
`DBusActivatable=true` would trigger if the port shipped one — see the
missing-`data/`-unit gap below). Not exercised by the drive script, which
only ever activates once. **gap.**

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
(`No audio sink found`, shown on the error page). The repeat-activation gap
above belongs to this unit as well as to the application unit. Unit:
**parity** for the single-activation path; **gap** for the repeat path (see
above — not double-counted, scored once there).

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
