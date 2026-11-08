# frozen_string_literal: true

# PoValidator is a strict, standalone reader of one .po file's text, used
# only to catch the class of defect `msgfmt -c` would catch at a real build's
# compile step.
#
# This port has no build step: `lib/gettext.rb` reads po/*.po straight from
# disk at runtime, so .mo files are never built and msgfmt-style catalogue
# validation never runs as a side effect of anything else this app does (see
# translation-parity.md). `lib/gettext.rb`'s own parser is deliberately
# lenient — a malformed entry there just falls back to the msgid, the same
# way a missing translation does — so it is the wrong tool to catch a
# malformed catalogue. This module is the substitute: it flags a string
# literal a real .po grammar would reject, a declared Plural-Forms header
# whose value is not a valid nplurals/plural expression (only asked for when
# the file actually uses msgid_plural — msgfmt itself only requires the
# header then), and a declared charset other than the UTF-8 every catalogue
# in this port is read as.
module PoValidator
  # gettext's own grammar for a Plural-Forms header value, e.g.
  # "nplurals=2; plural=(n != 1);".
  PLURAL_FORMS_PATTERN = /\Anplurals=\d+;\s*plural=.+;\s*\z/

  # One continuation or keyed line of a .po entry: an optional keyword
  # (msgctxt/msgid/msgid_plural/msgstr or msgstr[N]) followed by exactly one
  # double-quoted string, every quote inside it escaped. Nothing else is
  # valid as a non-comment, non-blank line in a .po file.
  LINE_PATTERN = /\A(?:msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?)?\s*"(?:[^"\\]|\\.)*"\z/

  # Every problem found in one .po file, each "path:line: reason" or
  # "path: reason" for a header-level problem. An empty array is what
  # `msgfmt -c` would also call clean.
  def self.errors(path)
    lines = File.readlines(path, encoding: 'UTF-8')
    string_literal_errors(path, lines) + header_errors(path, lines)
  end

  def self.string_literal_errors(path, lines)
    lines.each_with_index.filter_map do |line, index|
      stripped = line.strip
      unless stripped.empty? || stripped.start_with?('#')
        malformed_line(path, index, stripped)
      end
    end
  end

  def self.malformed_line(path, index, stripped)
    unless LINE_PATTERN.match?(stripped)
      "#{path}:#{index + 1}: malformed string literal: #{stripped.inspect}"
    end
  end

  def self.header_errors(path, lines)
    text = lines.join
    plural_forms_errors(path, text) + charset_errors(path, text)
  end

  def self.plural_forms_errors(path, text)
    if text.include?('msgid_plural')
      plural_form_errors_for(path, text[/Plural-Forms:\s*([^\\]*)\\n/, 1])
    else
      []
    end
  end

  def self.plural_form_errors_for(path, plural_forms)
    if plural_forms.nil?
      ["#{path}: uses msgid_plural but the header has no Plural-Forms"]
    elsif !PLURAL_FORMS_PATTERN.match?(plural_forms.strip)
      ["#{path}: header's Plural-Forms is not a valid nplurals/plural expression: #{plural_forms.inspect}"]
    else
      []
    end
  end

  def self.charset_errors(path, text)
    charset = text[/Content-Type:\s*text\/plain;\s*charset=([^\\]*)\\n/, 1]
    if charset && charset.strip.casecmp('UTF-8') != 0
      ["#{path}: header declares a non-UTF-8 charset: #{charset.inspect}"]
    else
      []
    end
  end

  private_class_method :string_literal_errors, :malformed_line, :header_errors, :plural_forms_errors,
                        :plural_form_errors_for, :charset_errors
end
