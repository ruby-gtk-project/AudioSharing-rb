# frozen_string_literal: true

# Drives the app's window: the sharing page, the address and its QR code, the
# copy button, the primary menu's about dialog, and the error page.
#
#   nix develop --command xvfb-run -a ruby test/drive_window.rb
#
# Screenshots land in tmp/shots. Each one is taken a tick after the step that
# changed the window, so GTK has laid the new content out before it is painted.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# The checks below read the untranslated strings, so the run is pinned to a
# language no catalogue covers whatever the developer's locale is.
ENV['LANGUAGE'] = 'en'

require 'main'
require_relative 'gtk_driver'

ADDRESS = 'rtsp://192.168.1.5:8554/audio'
ERROR_MESSAGE = 'No audio sink found'

app = App.new

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _|
  d.window { app.main_window.window }

  d.step('the window builds and presents') do
    app.main_window.then do |win|
      d.check('the window is visible') { win.window.visible? }
      d.check('the sharing page is the one showing') { win.stack.visible_child == win.sharing_page }
      d.check('the menu button carries the primary menu') { win.appmenu_button.menu_model == win.primary_menu }
      d.check('the menu has two sections') { win.primary_menu.n_items == 2 }
      d.check('the info paragraph is set') { win.info_label.text.include?('close this window') }
      d.check('the address is still empty') { win.address_label.text.empty? }
    end
  end

  d.step('the empty sharing page renders') { d.shot('01-sharing-page-empty') }

  d.step('an address fills in the label and the QR code') do
    app.main_window.then do |win|
      win.set_address(ADDRESS)

      d.check('the label shows the address') { win.address_label.text == ADDRESS }
      d.check('the picture has a paintable') { !win.qrcode_picture.paintable.nil? }
      d.check('the QR code is a version 3 symbol with its quiet zone') { QrCode.new(ADDRESS).width == 37 }
      d.check('the texture is square') do
        win.qrcode_picture.paintable.width == win.qrcode_picture.paintable.height
      end
    end
  end

  d.step('the address and QR code render') { d.shot('02-sharing-page-address') }

  # Gtk::Button#activate animates the press and emits `clicked` once that
  # animation is over, so the clipboard is only filled a tick later.
  d.step('the copy button is pressed') { app.main_window.copy_address_button.activate }

  d.step('the clipboard took the address and a toast says so') do
    Gdk::Display.default.clipboard.then do |clipboard|
      d.check('the clipboard has content') { !clipboard.content.nil? }
      d.check('the clipboard offers it as text') do
        clipboard.formats.mime_types.include?('text/plain;charset=utf-8')
      end
    end
    d.shot('03-copy-toast')
  end

  d.step('app.about opens the about dialog') do
    app.about_action.activate

    app.main_window.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the about dialog') { dialog.is_a?(Adwaita::AboutDialog) }
      d.check('it names the app') { dialog.application_name == 'Audio Sharing' }
      d.check('it carries the developers') { dialog.developers.size == 2 }
    end
  end

  d.step('the about dialog renders') { d.shot('04-about-dialog') }

  d.step('the dialog closes again') do
    app.main_window.window.visible_dialog&.close

    d.check('no dialog is up') { app.main_window.window.visible_dialog.nil? }
  end

  d.step('an error switches to the status page') do
    app.main_window.then do |win|
      win.show_error(ERROR_MESSAGE)

      d.check('the error page is showing') { win.stack.visible_child == win.error_status }
      d.check('the status page carries the message') { win.error_status.description == ERROR_MESSAGE }
      d.check('the status page keeps its title') { win.error_status.title == 'Unable to Share Audio' }
    end
  end

  d.step('the error page renders') { d.shot('05-error-page') }
end
