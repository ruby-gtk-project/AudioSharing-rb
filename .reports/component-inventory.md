# Component inventory — AudioSharing-rb

Surveyed against `origin/main` (Rust/libadwaita, meson build). Small app: one
window, one dialog, one custom paintable, one QR encoder, the application
object, and the config/translation/service layer underneath them. There is no
GSettings schema. The single declarative file is `data/gtk/window.ui`; every
other upstream source file is plain Rust.

Upstream tree read in full:
`git ls-tree -r --name-only origin/main` plus every file under `src/`,
`data/`, and `po/`.

Re-surveyed (round 3) after commit `71fa944` shipped the `data/` packaging
unit (`lib/data_files.rb` plus the three copied icon files) that round 2
had flagged as a gap. The sections below are updated in place rather than
re-written; the earlier rounds' corrections stay visible as history where
they were already recorded.

## Window — the app's only window

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `data/gtk/window.ui` + `src/ui/window.rs` | `lib/window.rb` | window (template root `AsApplicationWindow`) | yes |

Widget tree (from the `.ui` template, cross-checked against `window.rs`'s
template children and the `constructed()` signal wiring):

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | `audio-sharing-window` | — | `AsApplicationWindow` |
| `Gtk.WindowHandle` | 1 | — | — | wraps the whole content |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | top bar |
| `Gtk.MenuButton` (`appmenu_button`) | 1 | `circular` | — | `has-frame=false`, `primary=true`, `menu-model=primary_menu` |
| `Adw.ToastOverlay` (`toast_overlay`) | 1 | — | — | hosts the copy-confirmation toast |
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar-policy: never` |
| `Adw.Clamp` | 1 | — | — | `maximum-size: 500` |
| `Gtk.Stack` (`stack`) | 1 | — | — | two pages: unnamed sharing page, `"error"` |
| `Gtk.Box` (sharing page) | 1 | `audio-sharing` | — | vertical, spacing 12, centered |
| `Gtk.Picture` (`qrcode`) | 1 | `card` | — | 200×200, paintable is the `QrCodePaintable`'s texture |
| `Gtk.Box` (address box) | 1 | — | — | vertical, spacing 12, centered |
| `Gtk.Label` (`address_label`) | 1 | `title-3` | — | selectable, wraps |
| `Gtk.Button` (`copy_address_button`) | 1 | `pill` | `clicked` → copies address to clipboard, posts toast | label "_Copy to Clipboard" |
| `Gtk.Separator` | 1 | — | — | |
| `Gtk.Label` (info paragraph) | 1 | `caption` | — | the sharing-instructions text |
| `Adw.StatusPage` (`error_status`, stack page `"error"`) | 1 | — | — | title "Unable to Share Audio", icon `audio-volume-muted-symbolic` |
| `Gio.Menu` (`primary_menu`) | 1 | — | — | 2 sections: `app.help` (markup label with `↗`), `app.about` |
| `Adw.Toast` (built on click) | 1 | — | — | "Copied address to clipboard", timeout 2s |

Actions targeted (not installed here, installed on the app — see below):
`app.help`, `app.about` (menu items), `app.quit` (accelerator only, no menu
item upstream).

Port status: **present**, `lib/window.rb`. Matches widget-for-widget, CSS
class-for-class, including the dynamically built `Adwaita::Toast` on
`copy_address_button`'s `clicked` handler. `set_address` / `show_error` port
`AsApplicationWindow::set_address` / `show_error` 1:1.

## AboutDialog — the About window

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/ui/about_dialog.rs` (+ values from `data/de.haeckerfelix.AudioSharing.metainfo.xml.in.in`) | `lib/about_dialog.rb` | dialog | yes |

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | built via `from_appdata` upstream; port sets every field `from_appdata` would have read off the metainfo file, plus the one extra link (`add_link("Donate", ...)`) |

Fields set: application name/icon, developer name, version (with devel/VCS
suffix), comments (summary + 2 description paragraphs from the metainfo),
website, issue url, support url, GPL-3.0 license, developers (2), designers
(1), translator-credits, donate link.

Port status: **present**, `lib/about_dialog.rb`.

## QrCodePaintable — draws the QR code onto the window's `Gtk.Picture`

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/ui/qrcode_paintable.rs` | `lib/qrcode_paintable.rb` | behaviour (`GdkPaintable` impl, no CSS/no signals — it is drawn, not interacted with) | yes |

Not a widget by itself (implements `Gdk.Paintable`, consumed by the `qrcode`
`Gtk.Picture` above). Port substitutes Cairo + a `Gdk::Texture` for the direct
snapshot painting Rust does, because the Ruby bindings cannot dispatch
`snapshot` back into a Ruby-implemented paintable — documented in the file's
header comment. `set_qrcode` ports 1:1.

Port status: **present**, `lib/qrcode_paintable.rb`.

## QrCode — encodes a string as a QR module matrix

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/qrcode.rs` | `lib/qrcode.rb` | model (GObject in Rust, plain object in the port — no widget, no CSS, no signals) | yes |

Port substitutes `rqrcode_core` for the Rust `qrcode` crate (no Ruby binding
for `libqrencode`/`qrcode` exists), same substitution as the pilot port's
`qr_code_dialog.rb`. `items`/`width`/`height` port 1:1, quiet zone handled
explicitly since `rqrcode_core` does not add one.

Port status: **present**, `lib/qrcode.rb`.

## App — the application object (actions, menu wiring, accelerators, server startup)

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/app.rs` (`AsApplication`, `activate`) + `src/main.rs` (process init) | `lib/main.rb` (`App`) | application object | yes |

Actions installed on the app (`app.*`, consumed by the window's primary menu
and by the quit accelerator):

| Action | × | Signal | Notes |
|---|---:|---|---|
| `app.help` | 1 | `activate` → `Gtk::UriLauncher` opens the README url, rescues the launch error and warns (matches upstream's `if let Err(err) = result`) | |
| `app.about` | 1 | `activate` → builds and presents `AboutDialog` | |
| `app.quit` | 1 | `activate` → closes the window; accelerator `<primary>q` | no menu item, accelerator-only like upstream |

Non-UI behaviour ported alongside (not components, but the feature the window
exists to show): `setup_server`/`get_ip_addr`/`find_device_name` from
`src/app.rs`, in `lib/rtsp_server.rb` + `lib/gstreamer.rb`, including the
`client-connected` → `Gio::Notification` ("A client has established a
connection") upstream posts.

Port status: **present**. Note: upstream splits this into `src/app.rs` +
`src/main.rs`; the port merges both into a single `App` class in
`lib/main.rb` (file name differs from upstream's `main.rs`/`app.rs` split —
flagged here, not a gap, since every behaviour from both files is accounted
for in the class comment and body).

## Config / data files — not components, but every upstream data file's values are accounted for

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `src/config.rs.in` | `lib/config.rb` | constants | yes |
| `data/de.haeckerfelix.AudioSharing.desktop.in.in` | `lib/config.rb::DESKTOP_ENTRY` | data | yes |
| `data/de.haeckerfelix.AudioSharing.service.in` | `lib/config.rb::DBUS_SERVICE_*` | data | yes |
| `data/de.haeckerfelix.AudioSharing.metainfo.xml.in.in` | `lib/about_dialog.rb` (summary/description/urls) + `lib/config.rb` (urls) | data | yes |
| `data/de.haeckerfelix.AudioSharing.gresource.xml.in` | correspondence, not n/a — port has no GResource bundle because `window.ui`'s tree is inlined in `lib/window.rb` and `style.css` is empty upstream; the *bundling mechanism* doesn't carry over but it bundles nothing lost | — | correspondence |
| `data/icons/hicolor/scalable/apps/de.haeckerfelix.AudioSharing.svg`, `...Devel.svg`, `data/icons/hicolor/symbolic/apps/de.haeckerfelix.AudioSharing-symbolic.svg` | same three files, same paths, copied verbatim under `ruby`'s `data/icons/hicolor/**` | asset | yes (shipped in `71fa944`, see below) |
| `data/meson.build`'s `configure_file`/`i18n.merge_file`/`install_data` calls for the desktop entry, metainfo and D-Bus service file, plus `data/icons/meson.build`'s two icon `install_data` calls | `lib/data_files.rb` (`DataFiles.generate!`/`.install!`) | packaging/install | yes (shipped in `71fa944`, see below) |
| `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` | `lib/gettext.rb` | translation runtime | yes (translation *parity*, i.e. whether every msgid round-trips, is the `translation-parity` skill's job, not this one) |
| `meson_options.txt` (`profile` option) | `lib/config.rb::PROFILE`/`DEVELOPMENT` | data | yes |

`data/gtk/style.css` on `origin/main` is empty — there is no CSS to port.

## GSettings

Upstream ships no GSettings schema (`grep -r schema data/` and the meson
files show none) — nothing to port, nothing missing.

## Keyboard shortcuts

Only accelerator in the app: `app.quit` → `<primary>q`, ported in
`lib/main.rb`. There is no shortcuts window/dialog upstream.

## Summary

| File scanned | Maps to | Status |
|---|---|---|
| `data/gtk/window.ui` + `src/ui/window.rs` | `lib/window.rb` | present, full parity |
| `src/ui/about_dialog.rs` | `lib/about_dialog.rb` | present, full parity |
| `src/ui/qrcode_paintable.rs` | `lib/qrcode_paintable.rb` | present, full parity (Cairo substitution documented) |
| `src/qrcode.rs` | `lib/qrcode.rb` | present, full parity (`rqrcode_core` substitution documented) |
| `src/app.rs` + `src/main.rs` | `lib/main.rb` (`App`) | present, full parity (files merged, see note) |
| `src/config.rs.in` | `lib/config.rb` (constant *values* only) | present |
| `data/*.in(.in)` templates + `data/icons/**` | `lib/data_files.rb` + copied `data/` files | present (shipped `71fa944`, see correction below) |
| `po/*` | `lib/gettext.rb` | present (runtime), msgid-level parity not re-verified here |
| `src/ui/mod.rs` | n/a (module wiring only, no behaviour) | n/a |

**Correction (added in round 2, kept here as history — this gap is now
closed, do not read either sentence below as the current state):** this
document originally read "No missing components found", which was wrong —
`.reports/component-identification.md`'s addendum, written in the same
round, found the `data/` packaging tree (desktop entry, metainfo, D-Bus
service file, 3 icon files) had no port-side file at all. That gap was
closed in commit `71fa944` ("Ship the data/ packaging unit and
cover the repeat-activation guard"), which added `lib/data_files.rb`
(ported from `data/meson.build`'s `configure_file`/`i18n.merge_file`/
`install_data` calls) and copied the three icon files into
`data/icons/hicolor/**` on `ruby`, verified by `test/check_data_files.rb`.
As of this survey round, every upstream file that contributes a
user-facing **widget, action, accelerator, or packaging/identity
artifact** has a corresponding port-side file, and every widget/CSS
class/signal the `.ui` template and the Rust source declare is present in
the port. The `src/app.rs`/`src/main.rs` merge into one `App` class
remains a naming/organisation choice, not a dropped feature.

This inventory does not itself establish translation parity (msgid-by-msgid)
or test parity — those are the `translation-parity` and `test-parity` skills'
jobs and have not been run here.
