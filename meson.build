project('audio-sharing', 'rust',
          version: '0.2.4',
    meson_version: '>= 0.59.0',
          license: 'GPL-3.0-or-later',
)

gnome = import('gnome')
i18n = import('i18n')

# Dependencies
dependency('dbus-1')

dependency('glib-2.0', version: '>= 2.66')
dependency('gio-2.0', version: '>= 2.66')
dependency('gtk4', version: '>= 4.10.0')
dependency('libadwaita-1', version: '>=1.2.0')

dependency('gstreamer-1.0', version: '>= 1.16')
dependency('gstreamer-base-1.0', version: '>= 1.16')
dependency('gstreamer-audio-1.0', version: '>= 1.16')
dependency('gstreamer-plugins-base-1.0', version: '>= 1.16')
dependency('gstreamer-rtsp-server-1.0', version: '>= 1.16')

# Initialize project variables
name       = 'Audio Sharing'
base_id    = 'de.haeckerfelix.AudioSharing'
path_id    = '/de/haeckerfelix/AudioSharing'
app_id     = base_id
vcs_tag    = run_command('git', 'rev-parse', '--short', 'HEAD', check: false).stdout().strip()
profile    = get_option('profile')
datadir    = join_paths(get_option('prefix'), get_option('datadir'))
localedir  = join_paths(get_option('prefix'), get_option('localedir'))
bindir     = join_paths(get_option('prefix'), get_option('bindir'))

# Change app id for development builds
if profile == 'development'
  app_id = '@0@.Devel'.format(app_id)
endif

subdir('data')
subdir('src')
subdir('po')
