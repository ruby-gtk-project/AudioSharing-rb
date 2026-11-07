# frozen_string_literal: true

# Checks the catalogues in po/: every language po/LINGUAS
# lists parses, the app's own msgids are translated where the catalogue has
# them, and the locale environment picks the catalogue gettext would pick.
#
#   nix develop --command xvfb-run -a ruby test/check_translations.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'gettext'
require 'window'
require 'about_dialog'

# The strings this port asks the catalogues for.
MSGIDS = [
  'Menu',
  '_Copy to Clipboard',
  Window::INFO_TEXT,
  'Unable to Share Audio',
  'Open _Help <sup>↗</sup>',
  '_About Audio Sharing',
  'Copied address to clipboard',
  'A client has established a connection',
  'Audio playback from this device gets shared.',
  'translator-credits',
  'Donate',
  AboutDialog::SUMMARY,
  *AboutDialog::DESCRIPTION,
  AboutDialog::DEVELOPER_NAME,
].freeze

# A translation to prove the right catalogue is read, per locale.
SAMPLES = {
  'de'    => ['Menu', 'Menü'],
  'fr'    => ['Donate', 'Faire un don'],
  'pt_BR' => ['Unable to Share Audio', 'Não foi possível compartilhar áudio'],
}.freeze

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

puts "po/LINGUAS lists #{Gettext.linguas.size} languages"
check('every listed language has a catalogue') do
  Gettext.linguas.all? { |language| File.readable?(File.join(Gettext::LOCALEDIR, "#{language}.po")) }
end

puts 'every catalogue parses'
translated = 0
Gettext.linguas.each do |language|
  Gettext.parse(File.read(File.join(Gettext::LOCALEDIR, "#{language}.po"), encoding: 'UTF-8')).then do |messages|
    if messages.any?
      translated += 1
    end
    check("#{language}: #{messages.size} messages, none empty") do
      messages.none? { |msgid, msgstr| msgid.empty? || msgstr.empty? }
    end
  end
end

# kab.po is in LINGUAS with every msgstr still empty, so a catalogue with no
# messages is a translation that has not started, not a parse failure.
check("#{translated} of #{Gettext.linguas.size} catalogues carry translations") { translated >= 50 }

puts 'the app’s msgids are the ones the catalogues carry'
Gettext.parse(File.read(File.join(Gettext::LOCALEDIR, 'de.po'), encoding: 'UTF-8')).then do |german|
  MSGIDS.each do |msgid|
    check("de translates #{msgid[0, 40].inspect}") { german.key?(msgid) }
  end
end

puts 'the locale environment selects the catalogue'
SAMPLES.each do |locale, (msgid, expected)|
  ENV['LANGUAGE'] = locale
  Gettext.reset
  check("LANGUAGE=#{locale} reads #{locale}.po") { Gettext.locale == locale }
  check("LANGUAGE=#{locale} translates #{msgid.inspect}") { Gettext.translate(msgid) == expected }
end

ENV['LANGUAGE'] = 'de_CH.UTF-8@euro'
Gettext.reset
check('a locale with an encoding and a modifier still finds its catalogue') { Gettext.locale == 'de_CH' }

ENV['LANGUAGE'] = 'xx'
Gettext.reset
check('an untranslated locale falls back to the msgid') { Gettext.translate('Menu') == 'Menu' }

puts
puts(@failures.empty? ? 'TRANSLATIONS OK' : "TRANSLATIONS FAILED (#{@failures.size})")
exit(@failures.empty? ? 0 : 1)
