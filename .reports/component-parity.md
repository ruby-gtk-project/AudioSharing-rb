# Component parity — AudioSharing-rb

## Round 4 update (`ruby` @ `9265877`)

Re-verified against the current tip. The one commit since this report's
last round (`9265877`, "Generate per-locale Name[xx]/Keywords[xx] and
metainfo xml:lang entries, add an offline .po strict-parse check") touches
only `lib/data_files.rb` (per-locale generation, inside the already-closed
`data/` packaging unit below), `lib/gettext.rb` (`catalogue_for`, a reader
helper, no widget), and a new `lib/po_validator.rb` (a standalone text
parser, no widget, no CSS, no signal — it is not a GTK component by this
skill's own definition, the same reasoning this report already applies to
`lib/qrcode.rb`). **No unit's widget/CSS/signal set changed.** The 12/12
verdict below is unchanged; the `data/` unit's section is updated in place
to note it now also emits the per-locale `Name[xx]=`/`Keywords[xx]=` and
`xml:lang` content tracked as closed gaps in `translation-parity.md`.

| | |
|---|---|
| Upstream | `main` @ `a4b9350` |
| Port | `ruby` @ `9908947` (re-verified this round; previous round was `f476341`) |
| Units with full parity | 12 / 12 — the `data/` packaging gap this report used to carry was closed in `71fa944` ("Ship the data/ packaging unit and cover the repeat-activation guard"); see the corrected section below. `9908947` added the developer/branding/hardware/screenshot/release blocks to the same unit's metainfo without changing the verdict. |

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

**Repeat-activation guard — fixed and now covered.** Upstream's `activate`
checks `self.window.get()` and, on a second activation, presents the
existing window and returns before reaching `setup_server`
(`src/app.rs:40-47`). Commit `165d81e` ("Guard App#activate against a
second activation restarting the server") added `App#activate` with a
`window_built?` check (`lib/main.rb`): a second activation now only
presents the window, matching upstream's single-setup behaviour. Commit
`71fa944` then added the regression test this report used to flag as
missing: `test/drive_window.rb`'s "a second activation only re-presents
the window" step stubs `RtspServer#start`, calls `App#activate` a second
time, and asserts no second window was built and `starts.zero?`. Re-run
live this round (`nix develop --command xvfb-run -a ruby
test/drive_window.rb`, 85/85 checks green) — the step passes. **parity,
with regression coverage.**

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

## Unit: data/ packaging — `data/*.in.in`, `data/icons/**`, `data/gtk/style.css` → `lib/data_files.rb` + `data/**`

**Closed this round (previously scored "gap" in this report).** Commit
`71fa944` ("Ship the data/ packaging unit and cover the repeat-activation
guard") added `lib/data_files.rb` plus the three generated/copied files it
ports:

- `data/de.haeckerfelix.AudioSharing.desktop` — `DataFiles.desktop_entry`,
  built from `Config::DESKTOP_ENTRY`, the same constant this report
  previously called a dead end. It is read now: `Keywords=`,
  `Categories=`, `DBusActivatable=true` and the rest all round-trip.
- `data/de.haeckerfelix.AudioSharing.metainfo.xml` — `DataFiles.metainfo`,
  sourced from `AboutDialog::SUMMARY`/`DESCRIPTION`/`DEVELOPER_NAME` so the
  about dialog and the metainfo cannot drift apart.
- `data/de.haeckerfelix.AudioSharing.service` — `Config::DBUS_SERVICE_NAME`/
  `DBUS_SERVICE_ARGUMENT`, no longer dead constants.
- The three icon files (`...svg`, `...Devel.svg`, `...-symbolic.svg`) are
  copied verbatim under `data/icons/hicolor/**`, so
  `Gtk::Window.set_default_icon_name(Config::APP_ID)`
  (`lib/main.rb#configure_process`) now names an icon that exists on disk
  in this tree, not one that resolves to the missing-icon placeholder.

`test/check_data_files.rb` (run live this round, `DATA FILES OK`, 34
checks — up from 11, after `9908947` added the developer id/branding/
hardware/screenshot/release assertions) checks the committed files carry
the app id, summary, both description paragraphs, developer name,
homepage and contribute links, developer id block, both branding
colours, the minimum display length, all three supported controls, the
screenshot and its caption, and every release version upstream lists;
that `DataFiles.generate!` reproduces the committed desktop entry and
metainfo byte for byte (idempotency); and that all three icon files are
present. `data/gtk/style.css` is empty upstream, so there is nothing to
port there — unchanged from the base inventory.

Unit: **parity.**

## Rules check

- No app-wide totals substituted for per-unit comparison above.
- Every extra (none found beyond house-style restructuring already recorded
  as correspondences in the base inventory) is accounted for.
- The repeat-activation and `data/`-unit gaps this report used to carry are
  both closed, each with the commit and the live test run that proves it,
  not just asserted.
