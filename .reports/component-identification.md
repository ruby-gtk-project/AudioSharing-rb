# Component identification — addendum

This supplements `.reports/component-inventory.md` (already on `ruby`,
produced by an earlier run of this skill). That document is accurate as far
as it goes for the eleven numbered rows it lists. Re-running Step 1 of the
skill — "find the `.blp`/`.ui` files first" — against `origin/main` turns up
one more unit the original pass did not give its own row, because it has no
`.blp`/`.ui` and no `.rs`: the **`data/` packaging tree**.

## Missing unit: `data/` → nothing

| Upstream file | Kind | Port file |
|---|---|---|
| `data/de.haeckerfelix.AudioSharing.desktop.in.in` | desktop entry | **none** |
| `data/de.haeckerfelix.AudioSharing.metainfo.xml.in.in` | AppStream metainfo | **none** |
| `data/de.haeckerfelix.AudioSharing.service.in` | D-Bus service file | **none** |
| `data/icons/hicolor/scalable/apps/de.haeckerfelix.AudioSharing.svg` | app icon | **none** |
| `data/icons/hicolor/scalable/apps/de.haeckerfelix.AudioSharing.Devel.svg` | devel app icon | **none** |
| `data/icons/hicolor/symbolic/apps/de.haeckerfelix.AudioSharing-symbolic.svg` | symbolic icon | **none** |
| `data/gtk/style.css` | stylesheet | correspondence — upstream's is 0 bytes, nothing to port (already noted in the base report) |

`lib/config.rb` mirrors the *values* these files would carry
(`Config::DESKTOP_ENTRY`, `Config::DBUS_SERVICE_NAME`,
`Config::DBUS_SERVICE_ARGUMENT`) as Ruby constants, which is why the base
report's row 10 ("config") reads "yes". But a constant is not a file: a
`grep -rn 'DESKTOP_ENTRY\|DBUS_SERVICE' lib/ exe/` run on `ruby` @ `c038da2`
shows those constants are read nowhere else in the port. No `.desktop` file,
no `.service` file, no `metainfo.xml`, and no `.svg` icon exists anywhere in
the `ruby` branch's tree (`find . -iname '*.desktop*' -o -iname '*metainfo*'
-o -iname '*.svg'` returns nothing).

This is the unit `component-parity.md` and `translation-parity.md` both
track as **Unit 12** / the source of four real translation gaps, so it is
recorded here as its own row rather than folded silently into row 10.

Everything else in the base inventory (rows 1–11) still stands; this
addendum does not repeat it.
