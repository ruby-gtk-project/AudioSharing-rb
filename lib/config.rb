# frozen_string_literal: true

# Config holds the build-time values the app reads about itself.
#
# Ported from upstream's src/config.rs.in, which meson fills in from the
# variables in its meson.build (name, ids, version, profile, the vcs tag and
# the install directories), together with the two generated data files that
# carry the same values into the desktop session:
# data/de.haeckerfelix.AudioSharing.desktop.in.in and
# data/de.haeckerfelix.AudioSharing.service.in.
#
# There is no configure step in a Ruby port, so the substitutions happen here:
# the fixed values are constants, the profile comes from the environment the
# way meson's `-Dprofile=` option selects it, and the vcs tag is read out of
# the checkout instead of from `git rev-parse` at build time.
module Config
  # Upstream's meson.build project variables.
  NAME = 'Audio Sharing'
  PKGNAME = 'audio-sharing'
  BASE_ID = 'de.haeckerfelix.AudioSharing'
  PATH_ID = '/de/haeckerfelix/AudioSharing'
  VERSION = '0.2.4'

  # meson_options.txt offers 'default' and 'development'; the development
  # profile renames the app id so both can be installed side by side.
  DEVELOPMENT = 'development'
  PROFILE = ENV.fetch('AUDIO_SHARING_PROFILE', 'default')
  PROFILE_APP_IDS = { DEVELOPMENT => "#{BASE_ID}.Devel" }.freeze
  APP_ID = PROFILE_APP_IDS.fetch(PROFILE, BASE_ID)

  # Upstream's localedir and datadir. In this port the catalogues and the data
  # files live in the source tree next to lib/.
  ROOT = File.expand_path('..', __dir__)
  LOCALEDIR = File.join(ROOT, 'po')
  DATADIR = File.join(ROOT, 'data')

  # data/de.haeckerfelix.AudioSharing.desktop.in.in, field for field. The
  # comments upstream leaves for translators belong to the catalogue, so only
  # the values are here.
  DESKTOP_ENTRY = {
    'Name'                => NAME,
    'Icon'                => APP_ID,
    'Exec'                => PKGNAME,
    'Terminal'            => 'false',
    'Type'                => 'Application',
    'StartupNotify'       => 'true',
    'Categories'          => 'GNOME;GTK;Audio;AudioVideo;',
    'Keywords'            => 'Gnome;GTK;audio;sharing;sound;',
    'DBusActivatable'     => 'true',
    'X-Purism-FormFactor' => 'Workstation;Mobile;',
  }.freeze

  # data/de.haeckerfelix.AudioSharing.service.in: the D-Bus name the desktop
  # file's DBusActivatable=true starts the app under, and the argument that
  # service file passes.
  DBUS_SERVICE_NAME = APP_ID
  DBUS_SERVICE_ARGUMENT = '--gapplication-service'

  # The metainfo URLs the about dialog shows.
  HOMEPAGE_URL = 'https://apps.gnome.org/AudioSharing/'
  BUGTRACKER_URL = 'https://gitlab.gnome.org/World/AudioSharing/issues'
  DONATION_URL = 'https://liberapay.com/haecker-felix'
  CONTACT_URL = 'https://matrix.to/#/#audio-sharing:gnome.org'
  VCS_BROWSER_URL = 'https://gitlab.gnome.org/World/AudioSharing'
  TRANSLATE_URL = 'https://l10n.gnome.org/module/AudioSharing/'

  # The short commit the build was made from. meson runs `git rev-parse
  # --short HEAD` and bakes the answer in; reading the refs directly costs no
  # subprocess and gives the empty string in an exported tree, which is what
  # meson's `check: false` leaves behind too.
  def self.vcs_tag
    @vcs_tag ||= read_vcs_tag
  end

  # Whether this is a development build, as upstream's about dialog asks.
  def self.development? = PROFILE == DEVELOPMENT

  # The version string the about dialog shows: development builds carry the
  # commit they were built from.
  def self.display_version
    if development?
      "#{VERSION}-#{vcs_tag} (devel)"
    else
      VERSION
    end
  end

  def self.read_vcs_tag
    git_dir = File.join(ROOT, '.git')
    head = File.join(git_dir, 'HEAD')
    if File.readable?(head)
      resolve_head(git_dir, File.read(head).strip)
    else
      ''
    end
  end

  def self.resolve_head(git_dir, head)
    if head.start_with?('ref: ')
      resolve_ref(git_dir, head.delete_prefix('ref: '))
    else
      head[0, 7]
    end
  end

  def self.resolve_ref(git_dir, ref)
    path = File.join(git_dir, ref)
    if File.readable?(path)
      File.read(path).strip[0, 7]
    else
      resolve_packed_ref(git_dir, ref)
    end
  end

  def self.resolve_packed_ref(git_dir, ref)
    packed = File.join(git_dir, 'packed-refs')
    if File.readable?(packed)
      File.readlines(packed).grep(/ #{Regexp.escape(ref)}$/).first.to_s[0, 7]
    else
      ''
    end
  end

  private_class_method :read_vcs_tag, :resolve_head, :resolve_ref, :resolve_packed_ref
end
