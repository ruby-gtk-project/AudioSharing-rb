# frozen_string_literal: true

require 'fileutils'

require_relative 'config'
require_relative 'about_dialog'

# DataFiles builds and installs the desktop-session files a packaged install
# needs to find this app.
#
# Ported from upstream's data/meson.build — the `configure_file`/
# `i18n.merge_file`/`install_data` calls that turn
# data/de.haeckerfelix.AudioSharing.desktop.in.in,
# data/de.haeckerfelix.AudioSharing.metainfo.xml.in.in and
# data/de.haeckerfelix.AudioSharing.service.in into installed files under
# $datadir, together with data/icons/meson.build's two `install_data` calls
# for the app icon. There is no meson configure step in this port, so the
# `@APP_ID@`/`@NAME@`/`@PKGNAME@`/`@BINDIR@` substitutions those templates
# ask for happen here instead, filled in from the very
# `Config::DESKTOP_ENTRY`/`Config::DBUS_SERVICE_NAME`/
# `Config::DBUS_SERVICE_ARGUMENT` constants that `lib/config.rb` already
# built for this purpose.
module DataFiles
  # Where meson's `install_data` calls would put these files under a
  # `--prefix`-relative $datadir. This port has no install prefix, so
  # `install!` targets the XDG base directory a non-root install writes to.
  XDG_DATA_HOME = ENV.fetch('XDG_DATA_HOME') { File.join(Dir.home, '.local', 'share') }

  DESKTOP_FILE = "#{Config::APP_ID}.desktop"
  METAINFO_FILE = "#{Config::APP_ID}.metainfo.xml"
  SERVICE_FILE = "#{Config::APP_ID}.service"
  ICON_FILE = "#{Config::APP_ID}.svg"
  SYMBOLIC_ICON_FILE = "#{Config::APP_ID}-symbolic.svg"

  # data/icons/meson.build's two install_data destinations, relative to
  # Config::DATADIR.
  SCALABLE_ICON_DIR = File.join('icons', 'hicolor', 'scalable', 'apps')
  SYMBOLIC_ICON_DIR = File.join('icons', 'hicolor', 'symbolic', 'apps')

  # data/de.haeckerfelix.AudioSharing.desktop.in.in, substituted the way
  # `i18n.merge_file`'s `configuration_data` would: one `Key=Value` line per
  # entry, in the order upstream's template lists them.
  def self.desktop_entry
    "[Desktop Entry]\n#{Config::DESKTOP_ENTRY.map { |key, value| "#{key}=#{value}" }.join("\n")}\n"
  end

  # meson's default --prefix of /usr, the shipped file's substitution for
  # `@BINDIR@` — a real install passes the Ruby that will actually run it
  # instead, which is what `install!` below does.
  DEFAULT_BINDIR = '/usr/bin'

  # data/de.haeckerfelix.AudioSharing.service.in, substituted with meson's
  # `bindir` variable.
  def self.service_entry(bindir: DEFAULT_BINDIR)
    "[D-BUS Service]\nName=#{Config::DBUS_SERVICE_NAME}\n" \
      "Exec=#{bindir}/#{Config::PKGNAME} #{Config::DBUS_SERVICE_ARGUMENT}\n"
  end

  # data/de.haeckerfelix.AudioSharing.metainfo.xml.in.in, substituted with
  # the same summary, description, developer name and url constants the
  # about dialog shows, so the two cannot drift apart the way a hand-kept
  # metainfo file could.
  def self.metainfo
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <component type="desktop-application">
        <id>#{Config::APP_ID}</id>
        <name>#{Config::NAME}</name>
        <translation type="gettext">#{Config::PKGNAME}</translation>
        <launchable type="desktop-id">#{Config::APP_ID}.desktop</launchable>
        <summary>#{AboutDialog::SUMMARY}</summary>
        <description>
      #{description_paragraphs}
        </description>
        <content_rating type="oars-1.0"/>
        <developer_name>#{AboutDialog::DEVELOPER_NAME}</developer_name>
        <metadata_license>CC0-1.0</metadata_license>
        <project_license>GPL-3.0-or-later</project_license>
        <url type="homepage">#{Config::HOMEPAGE_URL}</url>
        <url type="bugtracker">#{Config::BUGTRACKER_URL}</url>
        <url type="donation">#{Config::DONATION_URL}</url>
        <url type="translate">#{Config::TRANSLATE_URL}</url>
        <url type="contact">#{Config::CONTACT_URL}</url>
        <url type="vcs-browser">#{Config::VCS_BROWSER_URL}</url>
      </component>
    XML
  end

  def self.description_paragraphs
    AboutDialog::DESCRIPTION.map { |paragraph| "    <p>\n      #{paragraph}\n    </p>" }.join("\n")
  end

  # (Re)writes the three generated files into the source tree's data/ —
  # Config::DATADIR — which is what gets committed and what `install!` below
  # reads from.
  def self.generate!
    FileUtils.mkdir_p(Config::DATADIR)
    File.write(File.join(Config::DATADIR, DESKTOP_FILE), desktop_entry)
    File.write(File.join(Config::DATADIR, METAINFO_FILE), metainfo)
    File.write(File.join(Config::DATADIR, SERVICE_FILE), service_entry)
  end

  # Upstream's install_data calls, reproduced for a user-level install: the
  # desktop entry under $datadir/applications, the metainfo under
  # $datadir/metainfo, the D-Bus service file under
  # $datadir/dbus-1/services, and the two icons under
  # $datadir/icons/hicolor/{scalable,symbolic}/apps. The generated files are
  # (re)written first, so an install always carries the current constants.
  def self.install!(datadir = XDG_DATA_HOME)
    generate!
    install_file(DESKTOP_FILE, File.join(datadir, 'applications'))
    install_file(METAINFO_FILE, File.join(datadir, 'metainfo'))
    install_service_file(File.join(datadir, 'dbus-1', 'services'))
    install_file(ICON_FILE, File.join(datadir, SCALABLE_ICON_DIR), from: SCALABLE_ICON_DIR)
    install_file(SYMBOLIC_ICON_FILE, File.join(datadir, SYMBOLIC_ICON_DIR), from: SYMBOLIC_ICON_DIR)
  end

  # The D-Bus service file is the one generated file whose content depends
  # on where the running Ruby actually installs executables, so an install
  # writes it fresh with that real bindir rather than copying the shipped
  # copy's placeholder one.
  def self.install_service_file(dest_dir)
    FileUtils.mkdir_p(dest_dir)
    File.write(File.join(dest_dir, SERVICE_FILE), service_entry(bindir: RbConfig::CONFIG.fetch('bindir')))
  end

  def self.install_file(name, dest_dir, from: nil)
    source = File.join(Config::DATADIR, *[from, name].compact)
    FileUtils.mkdir_p(dest_dir)
    FileUtils.cp(source, File.join(dest_dir, name))
  end

  private_class_method :description_paragraphs, :install_file, :install_service_file
end
