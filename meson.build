project('audio-sharing', 'rust',
          version: '0.1.0',
    meson_version: '>= 0.50.0',
          license: 'GPL-3.0-or-later',
)

# Dependencies
dependency('glib-2.0', version: '>= 2.66')
dependency('gio-2.0', version: '>= 2.66')
dependency('gtk4', version: '>= 4.0.0')
dependency('libadwaita-1', version: '>=1.0.0')

dependency('gstreamer-1.0', version: '>= 1.16')
dependency('gstreamer-base-1.0', version: '>= 1.16')
dependency('gstreamer-audio-1.0', version: '>= 1.16')

# Initialize project variables
name       = 'Audio Sharing'
app_id     = 'de.haeckerfelix.AudioSharing'
profile    = get_option('profile')
vcs_tag    = run_command('git', 'rev-parse', '--short', 'HEAD').stdout().strip()
localedir  = join_paths(get_option('prefix'), get_option('localedir'))
datadir    = get_option('datadir')
pkgdatadir = join_paths(get_option('prefix'), datadir, meson.project_name())

# Change app id for development builds
if profile == 'development'
  app_id = '@0@.Devel'.format(app_id)
endif

# Setup pre-commit hook for ensuring coding style is always consistent
if profile == 'development'
    message('Setting up git pre-commit hook..')
    run_command('mkdir', '.git/hooks/')
    run_command('cp', '-f', 'build-aux/pre-commit.hook', '.git/hooks/pre-commit')
endif

i18n = import('i18n')

subdir('data')
subdir('src')
subdir('po')

# Postinstall script (Update icon cache, gsettings, ...)
meson.add_install_script('build-aux/meson/postinstall.py')

meson.add_dist_script(
  'build-aux/dist-vendor.sh',
  meson.source_root(),
  join_paths(meson.build_root(), 'meson-dist', meson.project_name() + '-' + meson.project_version())
)
