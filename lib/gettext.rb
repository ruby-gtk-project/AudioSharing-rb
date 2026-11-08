# frozen_string_literal: true

require_relative 'config'

# Gettext translates the app's user visible strings.
#
# Ported from the translation setup in upstream's src/main.rs — setlocale,
# bindtextdomain(PKGNAME, LOCALEDIR), textdomain(PKGNAME) — and the `gettext`
# calls spread across src/app.rs, src/ui/about_dialog.rs and src/ui/window.rs,
# together with po/LINGUAS and the catalogues it lists.
#
# Upstream links against the C library's gettext, which reads compiled .mo
# files from the install tree. This port ships the .po catalogues themselves
# and reads them here, so there is no build step between a translation and a
# running app. The locale is picked the way gettext picks it: LANGUAGE first,
# as a priority list, then LC_ALL, LC_MESSAGES and LANG, with the bare
# language code tried when the full one has no catalogue.
module Gettext
  # The directory bindtextdomain points at, and the languages po/LINGUAS
  # lists. A locale outside that list has no catalogue to read.
  LOCALEDIR = Config::LOCALEDIR
  LINGUAS_FILE = 'LINGUAS'

  # The environment variables gettext consults, in its own order.
  LOCALE_VARIABLES = %w[LANGUAGE LC_ALL LC_MESSAGES LANG].freeze

  # The escapes a .po string can carry.
  UNESCAPES = {
    'n'  => "\n",
    't'  => "\t",
    'r'  => "\r",
    '"'  => '"',
    '\\' => '\\',
  }.freeze

  # Translates one message, giving back the msgid itself when the catalogue
  # has no translation for it — exactly what gettext(3) does.
  def self.translate(msgid)
    catalogue.fetch(msgid, msgid)
  end

  # The catalogue for the current locale, loaded once.
  def self.catalogue
    @catalogue ||= load_catalogue(locale)
  end

  # The catalogue for one named language, regardless of the environment's
  # locale negotiation — what data_files.rb asks for to build the
  # Name[xx]=/Keywords[xx]= lines and xml:lang elements i18n.merge_file and
  # itstool generate per entry in po/LINGUAS, one language at a time.
  def self.catalogue_for(language)
    @catalogues ||= {}
    @catalogues[language] ||= load_catalogue(language)
  end

  # The locale the catalogue is read for, or nil when none of the environment
  # variables names a language this app is translated into.
  def self.locale
    @locale ||= candidates.find { |candidate| linguas.include?(candidate) }
  end

  # The languages po/LINGUAS lists.
  def self.linguas
    @linguas ||= read_linguas
  end

  # Re-reads the environment. The locale is sampled once per process, as
  # setlocale does, so a test that changes the environment asks for this.
  def self.reset
    @locale = nil
    @catalogue = nil
    @catalogues = nil
    @linguas = nil
  end

  # Parses a .po file into a msgid => msgstr hash. Obsolete entries (the ones
  # commented out with `#~`), the header entry and messages left untranslated
  # are all left out, so a lookup for them falls back to the msgid.
  def self.parse(text)
    {}.tap do |messages|
      entries(text).each { |entry| store(messages, key_for(entry), entry) }
    end
  end

  # A message with a msgctxt is keyed the way a .mo file keys it: context,
  # EOT, msgid.
  def self.key_for(entry)
    if entry[:msgctxt].to_s.empty?
      entry[:msgid]
    else
      "#{entry[:msgctxt]}\u0004#{entry[:msgid]}"
    end
  end

  def self.store(messages, key, entry)
    if !entry[:msgid].to_s.empty? && !entry[:msgstr].to_s.empty?
      messages[key] = entry[:msgstr]
    end
  end

  # Splits a .po file into entries. A key line opens a string that the
  # following bare `"..."` lines continue.
  def self.entries(text)
    [].tap do |found|
      entry = {}
      field = nil
      text.each_line do |line|
        stripped = line.strip
        case stripped
        when '', /\A#~/
          found << entry
          entry = {}
          field = nil
        when /\A#/
          field = nil
        when /\A(msgctxt|msgid|msgstr)\s+"/
          field = Regexp.last_match(1).to_sym
          entry[field] = unescape(stripped)
        when /\Amsgstr\[0\]\s+"/
          field = :msgstr
          entry[field] = unescape(stripped)
        when /\Amsg/
          field = nil
        when /\A"/
          if field
            entry[field] = "#{entry[field]}#{unescape(stripped)}"
          end
        end
      end
      found << entry
    end
  end

  # The text of the first double quoted string on a line, with its escapes
  # resolved.
  def self.unescape(line)
    line[/"(.*)"/m, 1].to_s.gsub(/\\(.)/) { UNESCAPES.fetch(Regexp.last_match(1), Regexp.last_match(1)) }
  end

  def self.load_catalogue(name)
    path = File.join(LOCALEDIR, "#{name}.po")
    if name && File.readable?(path)
      parse(File.read(path, encoding: 'UTF-8'))
    else
      {}
    end
  end

  def self.read_linguas
    path = File.join(LOCALEDIR, LINGUAS_FILE)
    if File.readable?(path)
      File.read(path).split
    else
      []
    end
  end

  # The locales to try, most specific first: every entry of LANGUAGE, then the
  # first of the LC_* variables that is set, each followed by its bare
  # language code. 'de_CH.UTF-8@euro' contributes 'de_CH' and 'de'.
  def self.candidates
    requested.flat_map { |value| [value, value.split('_').first] }.uniq.reject(&:empty?)
  end

  def self.requested
    LOCALE_VARIABLES.flat_map { |variable| ENV.fetch(variable, '').split(':') }.map { |value| normalize(value) }
  end

  def self.normalize(value) = value.split('.').first.to_s.split('@').first.to_s

  private_class_method :key_for, :store, :load_catalogue, :read_linguas, :candidates, :requested, :normalize

  # Mixed into the classes that show translated strings, so their code reads
  # like upstream's `gettext("…")` calls.
  def _(msgid) = Gettext.translate(msgid)
end
