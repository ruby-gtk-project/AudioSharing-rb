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

## Round-2 re-check (`ruby` @ `165d81e`)

Re-ran `find . -iname '*.desktop*' -o -iname '*metainfo*' -o -iname
'*.svg'` (excluding `.git`) and `find data -type f` against the current
tip: both still return nothing. The `data/` unit named above is still
missing, unchanged since the previous round. The one commit since then
(`165d81e`) touched only `lib/main.rb`'s activation guard — see
`component-parity.md`'s application unit — and did not add any `data/`
file.

**Flagging an inconsistency this addendum's own base document carries.**
`component-inventory.md`'s summary table still reads "**No missing
components found**" and marks `data/icons/**` and
`data/*.gresource.xml.in` as `n/a` ("port has no GResource bundle" / "not a
UI component; not covered by this inventory"). This addendum — in the same
`.reports/` folder — already named the icons as a missing unit (the three
`.svg` rows above) when it was first written, and that correction was never
carried back into `component-inventory.md`'s own summary line. A reader
who reads only `component-inventory.md` still sees a clean "no missing
components" verdict that this addendum contradicts. Treated here as a
reporting gap in its own right: the base inventory was not corrected when
the addendum found what it found. See `accountability-ensurance.md` for
the write-up of this as a false-green risk.
