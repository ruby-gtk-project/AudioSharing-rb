# frozen_string_literal: true

require 'adwaita'

require_relative 'config'
require_relative 'gettext'

# AboutDialog is the app's about window.
#
# Ported from upstream's src/ui/about_dialog.rs, which builds an
# AdwAboutDialog with `from_appdata` and then fills in the credits and the
# donation link. `from_appdata` reads the installed appstream file, so the
# values it would pull out of
# data/de.haeckerfelix.AudioSharing.metainfo.xml.in.in — the name, the
# description, the licence and the urls — are set here instead.
class AboutDialog
  include Gettext

  DEVELOPERS = [
    'Felix Häcker <haeckerfelix@gnome.org>',
    'Maximiliano Sandoval <msandova@gnome.org>',
  ].freeze

  DESIGNERS = ['Tobias Bernard'].freeze

  DEVELOPER_NAME = 'Felix Häcker'

  # The metainfo's summary and the two paragraphs of its description.
  SUMMARY = 'Share your computer audio'

  DESCRIPTION = [
    'With Audio Sharing you can share your current computer audio playback in the form of an RTSP stream. ' \
    'This stream can then be played back by other devices, for example using VLC.',
    'By sharing the audio as a network stream, you can also use common devices that are not intended to be used ' \
    'as audio sinks (eg. smartphones) to receive it. For example, there are audio accessories that are not ' \
    'compatible with desktop computers (e.g. because the computer does not have a Bluetooth module installed). ' \
    'With the help of this app, the computer audio can be played back on a smartphone, which is then connected ' \
    'to the Bluetooth accessory.',
  ].freeze

  def build
    dialog.tap do |about|
      about.add_link(_('Donate'), Config::DONATION_URL)
    end
  end

  # Upstream's `about_dialog::show(&window)`: the dialog is presented inside
  # the window that asked for it.
  def present(parent) = dialog.present(parent)

  # Memoized widget methods

  def dialog
    @dialog ||= Adwaita::AboutDialog.new.tap do |about|
      about.application_name = Config::NAME
      about.application_icon = Config::APP_ID
      about.developer_name = DEVELOPER_NAME
      about.version = Config.display_version
      about.comments = comments
      about.website = Config::HOMEPAGE_URL
      about.issue_url = Config::BUGTRACKER_URL
      about.support_url = Config::CONTACT_URL
      about.license_type = Gtk::License::GPL_3_0
      about.developers = DEVELOPERS
      about.designers = DESIGNERS
      about.translator_credits = _('translator-credits')
    end
  end

  private

    def comments = [_(SUMMARY), *DESCRIPTION.map { |paragraph| _(paragraph) }].join("\n\n")
end
