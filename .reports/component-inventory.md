# Audio Sharing — upstream component inventory

Survey of `origin/main` (Rust / gtk-rs, GPL-3.0-or-later) against `lib/` on the
`ruby` branch. Produced with the `component-identification` skill. No app code
was written in this step.

Upstream is small: **5 Rust source files, 1 GtkBuilder `.ui`, 1 (empty)
stylesheet, no GSettings schema, no blueprint, no shortcuts window.** The whole
user-facing app is one window with two stack pages, one menu, one about dialog,
three app actions and one toast.

## Mapping summary

The house shape is the pilot's (`gnome-contacts-rb`): the real port lives in
top-level `lib/*.rb`, one file per upstream source file, with
`lib/audiosharing/application.rb` + `lib/audiosharing.rb` remaining the gem
plumbing that `exe/audiosharing` requires.

| # | Upstream file(s) | Port file | Kind | Exists on `ruby`? |
|---|---|---|---:|---|
| 1 | `src/main.rs`, `src/app.rs` | `lib/main.rb` | application | no |
| 2 | `src/ui/window.rs` + `data/gtk/window.ui` | `lib/window.rb` | window | no |
| 3 | `data/gtk/window.ui` (`menu primary_menu`) | `lib/window.rb` (in `primary_menu`) | menu | no |
| 4 | `data/gtk/window.ui` (`GtkStackPage` #1) | `lib/window.rb` (in `sharing_page`) | page | no |
| 5 | `data/gtk/window.ui` (`GtkStackPage` "error") | `lib/window.rb` (in `error_status`) | error state | no |
| 6 | `src/ui/about_dialog.rs` + metainfo | `lib/about_dialog.rb` | dialog | no |
| 7 | `src/ui/qrcode_paintable.rs` | `lib/qrcode_paintable.rb` | paintable | no |
| 8 | `src/qrcode.rs` | `lib/qrcode.rb` | model | no |
| 9 | `src/app.rs` (`setup_server`, `find_device_name`, `get_ip_addr`) | `lib/rtsp_server.rb` | service | no |
| 10 | `src/config.rs.in`, `data/*.in.in` | `lib/config.rb` | config | no |
| 11 | `po/*.po` (51 locales, 19 msgids) | `lib/gettext.rb` + `po/` | i18n | no |
| — | scaffold stub | `lib/audiosharing/application.rb` | stub | **yes** (placeholder only) |
| — | gem entry | `lib/audiosharing.rb` | plumbing | **yes** |

Nothing user-facing exists yet. `lib/audiosharing/application.rb` is the
generated scaffold: a `Gtk::Application`, an `Adwaita::ApplicationWindow`, an
`Adwaita::ToolbarView`, an empty `Adwaita::HeaderBar` and an
`Adwaita::StatusPage` reading "The Ruby port has not been written yet." It
contributes no upstream component.

---

## 1. `src/main.rs` + `src/app.rs` → `lib/main.rb` — the application

Not a widget class, but it owns the actions, the accelerator, the single-window
policy and the RTSP server startup that fills the window.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate` | upstream subclasses `adw::Application`; the Ruby bindings' `Adwaita::Application` is unusable, so the port uses `Gtk::Application` (as the pilot does) and an `Adwaita::ApplicationWindow` |
| `Gtk.UriLauncher` | 1 | — | — | `app.help` opens the upstream README on GitLab; logs on failure |
| `Gio.Notification` | 1 | — | — | not a widget; fired on `client-connected`, id `audio-sharing-playback` |

**Actions installed (`app.` prefix, all `Gio::SimpleAction`, no parameter):**

| Action | Accel | Does |
|---|---|---|
| `app.help` | — | `Gtk.UriLauncher` → `https://gitlab.gnome.org/World/AudioSharing/-/blob/main/README.md` |
| `app.about` | — | `about_dialog::show(&window)` |
| `app.quit` | `<primary>q` | `window.close()` |

**Activate behaviour:** if a window already exists it is `present`ed and
activate returns — actions are installed exactly once, on first activate.

**Startup (`main.rs`):** `glib::set_application_name(NAME)`,
`Gtk::Window.set_default_icon_name(APP_ID)`, two PulseAudio env vars
(`PULSE_PROP_application.icon_name`, `PULSE_PROP_application.metadata().name`),
gettext `setlocale`/`bindtextdomain`/`textdomain`, GResource load, and
`gstreamer::init()`. App id `de.haeckerfelix.AudioSharing`, resource base path
`/de/haeckerfelix/AudioSharing`.

Repeaters: none. Conditional: the whole action block and `setup_server` only on
the first activate.

## 2. `src/ui/window.rs` + `data/gtk/window.ui` → `lib/window.rb` — the one app window

`AsApplicationWindow : AdwApplicationWindow`. default 450×500, minimum
350×425.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `audio-sharing-window` | — | template root |
| `Gtk.WindowHandle` | 1 | — | — | whole window draggable |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Gtk.MenuButton` (`appmenu_button`) | 1 | `circular` | — | `child type="start"`, `has-frame=False`, `valign=center`, `primary=True`, icon `open-menu-symbolic`, tooltip "Menu", `menu-model=primary_menu` |
| `Adw.ToastOverlay` (`toast_overlay`) | 1 | — | — | hosts the copy confirmation toast |
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar-policy=never` |
| `Adw.Clamp` | 1 | — | — | `maximum-size=500` |
| `Gtk.Stack` (`stack`) | 1 | — | — | 2 pages: unnamed default, and `"error"` |
| `Gtk.StackPage` | 2 | — | — | not widgets — page wrappers (see 4 and 5) |
| `Adw.Toast` | 1 | — | — | built in code, "Copied address to clipboard", `timeout=2` |

**Public API the application calls:**

- `set_address(address)` — builds a `QrCode` from the address, sets
  `address_label`, hands the code to the paintable and the paintable to the
  `Gtk.Picture`.
- `show_error(message)` — `stack.visible_child_name = "error"` and
  `error_status.description = message`.

Repeaters: none. Conditional: the `"error"` stack page is only ever shown via
`show_error`; the default page is the startup child.

## 3. `data/gtk/window.ui` `menu primary_menu` → `lib/window.rb` — the primary menu

A `Gio::Menu` in two sections, 2 items, no `custom:` slots:

| Section | Label | Action | Notes |
|---|---|---|---|
| 1 | `Open _Help <sup>↗</sup>` | `app.help` | `use-markup=True` — the superscript arrow is markup, not a mnemonic |
| 2 | `_About Audio Sharing` | `app.about` | — |

## 4. `data/gtk/window.ui` first `GtkStackPage` → `lib/window.rb` `sharing_page` — the sharing view

The default, unnamed page. A vertical `Gtk.Box`, spacing 12, centred both ways,
h/v-expanding, 12px margins all round.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (outer) | 1 | `audio-sharing` | — | vertical, spacing 12, `halign/valign=center` |
| `Gtk.Picture` (`qrcode`) | 1 | `card` | — | 200×200 request, centred; paintable set by `set_address` |
| `Gtk.Box` (inner) | 1 | — | — | vertical, spacing 12, `halign=center` |
| `Gtk.Label` (`address_label`) | 1 | `title-3` | — | `selectable`, `wrap`, `justify=center`; text is `rtsp://<ip>:8554/audio` |
| `Gtk.Button` (`copy_address_button`) | 1 | `pill` | `clicked` → copies `address_label.text` to `Gdk::Display.default.clipboard`, then adds a 2s `Adw.Toast` | label `_Copy to Clipboard`, `use-underline`, `halign=center` |
| `Gtk.Separator` | 1 | — | — | — |
| `Gtk.Label` (explanatory) | 1 | `caption` | — | `wrap`, `justify=center`; the two-paragraph "You are currently sharing your audio…" / "To stop sharing, simply close this window." text |

## 5. `data/gtk/window.ui` `"error"` `GtkStackPage` → `lib/window.rb` `error_status` — the error state

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.StatusPage` (`error_status`) | 1 | — | — | title "Unable to Share Audio", icon `audio-volume-muted-symbolic`, description set at runtime |

Only reachable description upstream: `"No audio sink found"`, passed from
`app.rs` when `find_device_name()` returns `None`. Note this string is **not**
in `po/POTFILES.in`'s extracted catalogue — upstream does not translate it.

## 6. `src/ui/about_dialog.rs` → `lib/about_dialog.rb` — the about dialog

A free function upstream, not a subclass; `Adw.AboutDialog::from_appdata`
reading the GResource'd `metainfo.xml`. The Ruby bindings have no
`from_appdata`, so the port must set the same fields by hand from the metainfo
values recorded here.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | `present(Some(parent))` |

**Fields, from `about_dialog.rs` plus `data/de.haeckerfelix.AudioSharing.metainfo.xml.in.in`:**

- name "Audio Sharing", app id `de.haeckerfelix.AudioSharing`
- version: `VERSION`, or `"<VERSION>-<VCS_TAG> (devel)"` when `PROFILE == "development"` — **conditional**
- developers: `Felix Häcker <haeckerfelix@gnome.org>`, `Maximiliano Sandoval <msandova@gnome.org>`
- designers: `Tobias Bernard`
- translator credits: `gettext("translator-credits")`
- extra link: `gettext("Donate")` → `https://liberapay.com/haecker-felix`
- from metainfo: summary "Share your computer audio", developer name "Felix Häcker",
  licenses CC0-1.0 / GPL-3.0-or-later, homepage `https://apps.gnome.org/AudioSharing/`,
  issue URL `https://gitlab.gnome.org/World/AudioSharing/issues`,
  branding colours `#e56b5a` (light) / `#972b31` (dark)

## 7. `src/ui/qrcode_paintable.rs` → `lib/qrcode_paintable.rb` — the QR paintable

`QrCodePaintable` implements `Gdk.Paintable` (an interface implementation, not a
widget). Original author Bilal Elmoussaoui (from Decoder).

| Item | Kind | Notes |
|---|---|---|
| `Gdk.Paintable` | iface | implemented via `snapshot(snapshot, width, height)` |
| `Gtk.Snapshot` | type | `append_color` per module |
| `Graphene.Rect` | record | one per module plus one full-size background |

Drawing: white background rect over the full size, then for each module a black
rect (or fully transparent when light), on a grid of
`width / (qr.width + 2)` × `height / (qr.height + 2)` offset by one square —
i.e. a one-module quiet border on top of the code's own quiet zone.
`set_qrcode` replaces the code and calls `invalidate_contents`. With no code
set it paints `QrCode::default()` (an empty-string code).

**Port note:** Ruby cannot subclass `Gdk::Paintable`. The port should render the
modules with Cairo into a `Gdk::Texture` and set that on the `Gtk::Picture` —
the same substitution the pilot made in `gnome-contacts-rb/lib/qr_code_dialog.rb`.
`set_address` then re-renders rather than invalidating.

## 8. `src/qrcode.rs` → `lib/qrcode.rb` — the QR code model

A `GObject` with no widget in it. Properties: `content` (get/set/construct-only),
`width` (get), `height` (get); plus `items: Vec<Vec<bool>>`. Built in
`constructed` from the `qrcode` crate with `quiet_zone(true)` and
`module_dimensions(1, 1)`, rendered to chars and mapped to booleans by
non-whitespace. `Default` is `QrCode::new("")`.

**Port note:** no libqrencode/qrcode binding; use `rqrcode_core` (pure Ruby, as
the pilot does) and expose the same `items` / `width` / `height` shape.

## 9. `src/app.rs` server plumbing → `lib/rtsp_server.rb` — the sharing service

Not UI, but it is what decides between component 4 and component 5, so the port
needs it as its own file.

- `find_device_name()` — `Gst::DeviceMonitor`, first device with
  `device_class == "Audio/Sink"` and property `is-default == true`; returns its
  element's `device` property. `None` → `window.show_error("No audio sink found")`.
- `get_ip_addr()` — first interface that is up, not loopback, has an IP and
  whose name does not contain `virbr`; else `"0.0.0.0"`.
- `setup_server()` — `RTSPServer` with one `RTSPMediaFactory` mounted at
  `/audio`, shared, launch pipeline
  `pulsesrc device=<node>.monitor client-name=audio-sharing ! vorbisenc ! rtpvorbispay name=pay0 pt=96`,
  attached to the default main context; then
  `window.set_address("rtsp://<ip>:8554/audio")`.
- `client-connected` → the `Gio.Notification` in component 1.

## 10. `src/config.rs.in` + `data/*.in.in` → `lib/config.rb` — build-time config

Meson-substituted constants the UI reads: `APP_ID`, `PATH_ID`, `NAME`,
`PKGNAME`, `VERSION`, `VCS_TAG`, `PROFILE`, `DATADIR`, `LOCALEDIR`. The port has
no meson, so these become Ruby constants. `PROFILE == "development"` is a live
conditional in the about dialog (component 6).

Also here: the desktop entry (`Categories=GNOME;GTK;Audio;AudioVideo;`,
`Keywords=Gnome;GTK;audio;sharing;sound;`, `DBusActivatable=true`,
`X-Purism-FormFactor=Workstation;Mobile;`) and the D-Bus service file.

## 11. `po/` → `lib/gettext.rb` + `po/` — the catalogue

51 locales in `po/LINGUAS`; 10 files in `po/POTFILES.in`. **19 msgids**, of
which these are UI strings the port must carry:

`Menu` · `_Copy to Clipboard` · `Unable to Share Audio` ·
`Open _Help <sup>↗</sup>` · `_About Audio Sharing` ·
`A client has established a connection` ·
`Audio playback from this device gets shared.` · `translator-credits` ·
`Donate` · `Copied address to clipboard` ·
the long "You are currently sharing your audio…" body ·
plus the desktop/metainfo strings (`Share your computer audio`, the two
description paragraphs, the keyword list, `Felix Häcker`).

## Stylesheet

`data/gtk/style.css` is **0 bytes**. The classes `audio-sharing-window`
(component 2) and `audio-sharing` (component 4) are therefore applied and
nowhere defined — dead hooks upstream. Every other class used
(`circular`, `card`, `title-3`, `pill`, `caption`) is a stock libadwaita class.

## Not present upstream

No GSettings schema, no preferences dialog, no shortcuts window (the only
accelerator is `<primary>q`), no empty state other than component 5, no
submodules, no `.blp`, no sidebar or navigation view, no tests.
