# frozen_string_literal: true

# Checks the data/ packaging unit without a display: the desktop entry, the
# AppStream metainfo and the D-Bus service file all parse and carry the
# values lib/config.rb and lib/about_dialog.rb build, and the three icon
# files upstream ships all exist where upstream puts them.
#
#   nix develop --command ruby test/check_data_files.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'data_files'

@failures = []

def check(description)
  if yield
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}"
    @failures << description
  end
rescue StandardError => e
  puts "  FAIL #{description} (#{e.class}: #{e.message})"
  @failures << description
end

def desktop_entries(text)
  text.lines.drop(1).to_h { |line| line.chomp.split('=', 2) }
end

puts 'the desktop entry on disk matches Config::DESKTOP_ENTRY'
desktop_path = File.join(Config::DATADIR, DataFiles::DESKTOP_FILE)
check('the file exists') { File.readable?(desktop_path) }
desktop_entries(File.read(desktop_path)).then do |entries|
  check('it starts with the group header') { File.read(desktop_path).start_with?('[Desktop Entry]') }
  Config::DESKTOP_ENTRY.each do |key, value|
    check("#{key}=#{value}") { entries[key] == value }
  end
end

puts 'the desktop entry carries a localized Name[xx]/Keywords[xx] line per translated language'
desktop_text = File.read(desktop_path)
check('de translates Name') { desktop_text.include?('Name[de]=@NAME@') }
check('cs translates Name to something other than the msgid') { desktop_text.include?('Name[cs]=Sdílení zvuku') }
check('de translates Keywords') { desktop_text.include?('Keywords[de]=Gnome;GTK;audio;sharing;sound;Ton;freigeben;Klang;') }
check('a language with no translation for a msgid contributes no line') do
  # kab.po is in LINGUAS with every msgstr still empty (see
  # check_translations.rb), so it has no translation for any msgid.
  !desktop_text.include?('Name[kab]=') && !desktop_text.include?('Keywords[kab]=')
end
check('every Name[xx]/Keywords[xx] line names a language po/LINGUAS lists') do
  desktop_text.scan(/^(?:Name|Keywords)\[([^\]]+)\]=/).flatten.uniq.all? { |language| Gettext.linguas.include?(language) }
end

puts 'the D-Bus service file on disk matches Config::DBUS_SERVICE_NAME'
service_path = File.join(Config::DATADIR, DataFiles::SERVICE_FILE)
check('the file exists') { File.readable?(service_path) }
service_text = File.read(service_path)
check('it names the D-Bus service') { service_text.include?("Name=#{Config::DBUS_SERVICE_NAME}") }
check('it execs the package with the service argument') do
  service_text.include?("/#{Config::PKGNAME} #{Config::DBUS_SERVICE_ARGUMENT}")
end

puts 'the metainfo on disk matches the about dialog'
metainfo_path = File.join(Config::DATADIR, DataFiles::METAINFO_FILE)
check('the file exists') { File.readable?(metainfo_path) }
metainfo_text = File.read(metainfo_path)
check('it carries the app id') { metainfo_text.include?("<id>#{Config::APP_ID}</id>") }
check('it carries the summary') { metainfo_text.include?("<summary>#{AboutDialog::SUMMARY}</summary>") }
check('it carries both description paragraphs') do
  AboutDialog::DESCRIPTION.all? { |paragraph| metainfo_text.include?(paragraph) }
end
check('it carries the developer name') do
  metainfo_text.include?("<developer_name>#{AboutDialog::DEVELOPER_NAME}</developer_name>")
end
check('it links the homepage') { metainfo_text.include?(Config::HOMEPAGE_URL) }
check('it links the contribute page') { metainfo_text.include?(Config::CONTRIBUTE_URL) }
check('it carries the developer block with its id') do
  metainfo_text.include?("<developer id=\"#{DataFiles::DEVELOPER_ID}\">")
end
check('it carries both branding colours') do
  DataFiles::BRANDING_COLORS.values.all? { |color| metainfo_text.include?(color) }
end
check('it declares the minimum display length') do
  metainfo_text.include?("<display_length compare=\"ge\">#{DataFiles::MINIMUM_DISPLAY_LENGTH}</display_length>")
end
check('it declares all three supported controls') do
  DataFiles::SUPPORTED_CONTROLS.all? { |control| metainfo_text.include?("<control>#{control}</control>") }
end
check('it carries the screenshot and its caption') do
  metainfo_text.include?(DataFiles::SCREENSHOT_URL) && metainfo_text.include?(DataFiles::SCREENSHOT_CAPTION)
end
check('it carries every release version upstream lists') do
  DataFiles::RELEASES.all? { |release| metainfo_text.include?("version=\"#{release[:version]}\"") }
end
check('it closes the releases element') { metainfo_text.include?('</releases>') }
check('it carries a localized <name xml:lang> per translated language') do
  metainfo_text.include?('<name xml:lang="cs">Sdílení zvuku</name>')
end
check('it carries a localized <summary xml:lang> per translated language') do
  metainfo_text.include?('<summary xml:lang="de">Geben Sie die Tonausgabe Ihres Rechners frei</summary>')
end
check('every <name>/<summary> xml:lang names a language po/LINGUAS lists') do
  metainfo_text.scan(/<(?:name|summary) xml:lang="([^"]+)">/).flatten.uniq.all? { |language| Gettext.linguas.include?(language) }
end

puts 'DataFiles.generate! is idempotent and reproduces the committed files'
check('the desktop entry regenerates byte for byte') { DataFiles.desktop_entry == File.read(desktop_path) }
check('the metainfo regenerates byte for byte') { DataFiles.metainfo == metainfo_text }

puts 'the three icon files upstream ships are all present'
check('the scalable app icon exists') do
  File.readable?(File.join(Config::DATADIR, DataFiles::SCALABLE_ICON_DIR, DataFiles::ICON_FILE))
end
check('the devel scalable app icon exists') do
  File.readable?(File.join(Config::DATADIR, DataFiles::SCALABLE_ICON_DIR, "#{Config::APP_ID}.Devel.svg"))
end
check('the symbolic app icon exists') do
  File.readable?(File.join(Config::DATADIR, DataFiles::SYMBOLIC_ICON_DIR, DataFiles::SYMBOLIC_ICON_FILE))
end

puts
puts(@failures.empty? ? 'DATA FILES OK' : "DATA FILES FAILED (#{@failures.size})")
exit(@failures.empty? ? 0 : 1)
