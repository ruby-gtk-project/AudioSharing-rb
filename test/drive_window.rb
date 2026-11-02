# frozen_string_literal: true

# Drives the whole app headlessly: the RTSP server's startup verdict, the
# window and its geometry, the sharing page with its empty and filled QR code, the primary menu opened as a real
# popover, the copy button and the toast it raises, all three application
# actions, the about dialog, the error page, and the `<primary>q` accelerator
# fired as an actual key press.
#
#   nix develop --command xvfb-run -a ruby test/drive_window.rb
#
# Why this file exists: a GTK app that parses is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the Ruby bindings
# differ from the C API in ways only a run reveals.
#
# Screenshots land in tmp/shots. Each one is taken a tick after the step that
# changed the window, so GTK has laid the new content out before it is
# painted — read them, they show what no assertion thought to ask about.

require 'fileutils'
require 'rbconfig'

# Xvfb's default screen is 640x480, which is shorter than the 500px default
# height the window asks for — GTK silently clamps the window to the screen
# and the geometry checks below would then be measuring Xvfb, not the port.
# So the run puts itself on a screen with room, whatever it was started on.
if ENV['DRIVE_SCREEN'].nil?
  ENV['DRIVE_SCREEN'] = '1280x1024x24'
  begin
    exec(
      'xvfb-run',
      '-a',
      '-s',
      "-screen 0 #{ENV['DRIVE_SCREEN']}",
      RbConfig.ruby,
      __FILE__,
    )
  rescue Errno::ENOENT
    warn 'xvfb-run not found; staying on the display this was started with'
  end
end

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# The checks below read the untranslated strings, so the run is pinned to a
# language no catalogue covers whatever the developer's locale is.
ENV['LANGUAGE'] = 'en'

require 'main'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

ADDRESS = 'rtsp://192.168.1.5:8554/audio'
ERROR_MESSAGE = 'No audio sink found'

# A PulseAudio sink node name, and the pipeline upstream builds for it.
SINK_NODE_NAME = 'alsa_output.pci-0000_00_1f.3.analog-stereo'
LAUNCH_LINE = 'pulsesrc device=alsa_output.pci-0000_00_1f.3.analog-stereo.monitor ' \
              'client-name=audio-sharing ! vorbisenc ! rtpvorbispay name=pay0 pt=96'

# The QR symbol sizes the two addresses encode to, quiet zone included: the
# empty code the picture shows before an address is a version 1 symbol, the
# address a version 3 one.
# What the clipboard hands back when the next step asks it to paste.
PASTED = {}

EMPTY_QRCODE_WIDTH = 29
ADDRESS_QRCODE_WIDTH = 37

# The paintable's module size and the one-module inset it leaves, which
# together decide the texture it hands the picture.
def texture_side(modules) = (modules + (QrCodePaintable::PADDING * 2)) * QrCodePaintable::MODULE_SIZE

# A step cannot sleep: every step runs inside a GLib timeout, so the clock a
# sleep would wait on is dispatched by the very loop it would block. This
# iterates the default context without blocking until the deadline passes.
def pump(ms)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)).then do |deadline|
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      GLib::MainContext.default.iteration(false)
    end
  end
end

# Every Gtk::Label text in a widget tree.
#
# The toast an AdwToastOverlay raises is not readable as a property — there is
# no get_current_toast — and an AdwAboutDialog's add_link rows are not either,
# so the only way to assert those strings really reached the screen is to look
# at the widgets that were built.
def labels(widget, found = [])
  found.tap do
    if widget.is_a?(Gtk::Label)
      found << widget.label
    end
    widget.first_child.then do |first|
      child = first
      while child
        labels(child, found)
        child = child.next_sibling
      end
    end
  end
end

# One item's attribute out of a Gio::Menu section. The bindings unwrap the
# GVariant already, so what comes back is a plain Ruby value.
def item_attribute(section, index, name)
  section.get_item_attribute_value(index, name, nil)
end

# Runs xdotool against the display the driver is already on, quietly.
def xdotool(*args)
  system('xdotool', *args, out: File::NULL, err: File::NULL)
end

# The size of the screen this run ended up on. The geometry checks below are
# only meaningful on a screen the window fits in, so the run says which one it
# got and asserts it has room rather than quietly measuring Xvfb.
def screen_geometry = Gdk::Display.default.monitors.get_item(0).geometry

app = App.new

GtkDriver.drive(app, shots: SHOTS) do |d, _|
  d.window { app.main_window.window }

  d.step('the window builds and presents') do
    app.main_window.then do |win|
      d.check('the window is visible') { win.window.visible? }
      d.check('it is an Adwaita::ApplicationWindow') { win.window.is_a?(Adwaita::ApplicationWindow) }
      d.check('it is the only toplevel') { Gtk::Window.list_toplevels.length == 1 }
      d.check('its title is the app name') { win.window.title == 'Audio Sharing' }
      d.check('its icon is the application id') { win.window.icon_name == Config::APP_ID }
      d.check('the application id is the default profile one') { Config::APP_ID == 'de.haeckerfelix.AudioSharing' }
      d.check('the display has room for the window') do
        warn "display #{ENV['DISPLAY']} is #{screen_geometry.width}x#{screen_geometry.height}"
        screen_geometry.width >= Window::DEFAULT_WIDTH && screen_geometry.height >= Window::DEFAULT_HEIGHT
      end
      d.check('it opens at the size the template asks for') do
        win.window.default_size == [Window::DEFAULT_WIDTH, Window::DEFAULT_HEIGHT]
      end
      d.check('it refuses to shrink past the template minimum') do
        win.window.size_request == [Window::MINIMUM_WIDTH, Window::MINIMUM_HEIGHT]
      end
      d.check('the whole window is a drag handle') { win.window.content == win.window_handle }
      d.check('the clamp caps the content width') { win.clamp.maximum_size == Window::CLAMP_WIDTH }
      d.check('the stack has both pages') { win.stack.pages.n_items == 2 }
      d.check('the menu button carries the primary menu') { win.appmenu_button.menu_model == win.primary_menu }
      d.check('the menu has two sections') { win.primary_menu.n_items == 2 }
      d.check('the info paragraph is set') { win.info_label.text.include?('close this window') }
      d.check('the copy button is labelled') { win.copy_address_button.label == '_Copy to Clipboard' }
      d.check('the separator sits between the address and the paragraph') do
        win.separator.parent == win.sharing_page
      end
    end
  end

  # The server runs at the end of activate, before the driver's first step, so
  # the window the driver finds is already in whatever state the server put it
  # in. This machine has no audio sink — no PulseAudio server, no ALSA output —
  # so the device monitor listed nothing, the server was never started, and the
  # window came up on the error page saying so. That is upstream's behaviour on
  # such a machine too, not a failure of the port.
  d.step('the server reported what it found at startup') do
    app.main_window.then do |win|
      d.check('gstreamer is initialised') { !Gst.version_string.nil? }
      d.check('the pipeline elements upstream names are all installed') do
        %w[pulsesrc vorbisenc rtpvorbispay].all? { |element| !Gst::ElementFactory.find(element).nil? }
      end
      d.check('the device monitor found no default sink here') { app.rtsp_server.device_name.nil? }
      d.check('so the window came up on the error page') { win.stack.visible_child == win.error_status }
      d.check('saying there is no sink') { win.error_status.description == RtspServer::NO_SINK_MESSAGE }
      d.check('and the address was never set') { win.address_label.text.empty? }
      d.shot('00-no-audio-sink')
    end
  end

  d.step('the pieces the server would have used are upstream\'s') do
    d.check('the launch line is upstream pipeline') do
      format(RtspServer::LAUNCH, node_name: SINK_NODE_NAME) == LAUNCH_LINE
    end
    d.check('the address is rtsp on 8554 at /audio') do
      app.rtsp_server.address.match?(%r{\Artsp://\S+:8554/audio\z})
    end
    d.check('it carries an address off this machine, not the fallback') do
      app.rtsp_server.ip_address != RtspServer::FALLBACK_ADDRESS
    end
    d.check('the notification keeps upstream id') do
      RtspServer::NOTIFICATION_ID == 'audio-sharing-playback'
    end
    # Upstream sends this from the server's client-connected handler. There is
    # no server to connect to here, so the handler's body is called directly:
    # what is being checked is that it reaches Gio and comes back.
    d.check('sending the playback notification goes through') do
      app.rtsp_server.send(:notify_playback)
      true
    end
  end

  # Back to the sharing page for the rest of the run. Upstream's set_address
  # does not switch pages — the server either sets an address on the page the
  # stack already shows, or switches to the error one — so the page a machine
  # with a sink would have come up on is put back by hand here.
  d.step('the sharing page is put back up') do
    app.main_window.then do |win|
      win.stack.visible_child = win.sharing_page

      d.check('the sharing page is the one showing') { win.stack.visible_child == win.sharing_page }
    end
  end

  d.step('the empty state shows the empty code and no address') do
    app.main_window.then do |win|
      d.check('the address is still empty') { win.address_label.text.empty? }
      d.check('the picture already has a paintable') { !win.qrcode_picture.paintable.nil? }
      d.check('it is the empty string code') { win.paintable.qrcode.content.empty? }
      d.check('the empty code is a version 1 symbol') { win.paintable.qrcode.width == EMPTY_QRCODE_WIDTH }
      d.check('its texture is the inset symbol') do
        win.qrcode_picture.paintable.width == texture_side(EMPTY_QRCODE_WIDTH)
      end
      d.shot('01-sharing-page-empty')
    end
  end

  d.step('an address fills in the label and the QR code') do
    app.main_window.then do |win|
      win.set_address(ADDRESS)

      d.check('the label shows the address') { win.address_label.text == ADDRESS }
      d.check('the picture has a paintable') { !win.qrcode_picture.paintable.nil? }
      d.check('the code carries the address') { win.paintable.qrcode.content == ADDRESS }
      d.check('the QR code is a version 3 symbol with its quiet zone') do
        QrCode.new(ADDRESS).width == ADDRESS_QRCODE_WIDTH
      end
      d.check('the texture grew with the symbol') do
        win.qrcode_picture.paintable.width == texture_side(ADDRESS_QRCODE_WIDTH)
      end
      d.check('the texture is square') do
        win.qrcode_picture.paintable.width == win.qrcode_picture.paintable.height
      end
    end
  end

  d.step('the address and QR code render') { d.shot('02-sharing-page-address') }

  d.step('the primary menu names the two items and their actions') do
    app.main_window.then do |win|
      d.check('the help section has one item') { win.help_section.n_items == 1 }
      d.check('the help item keeps the markup label') do
        item_attribute(win.help_section, 0, 'label') == 'Open _Help <sup>↗</sup>'
      end
      d.check('the help item is marked up rather than mnemonic') do
        item_attribute(win.help_section, 0, 'use-markup') == true
      end
      d.check('the help item fires app.help') { item_attribute(win.help_section, 0, 'action') == 'app.help' }
      d.check('the about section has one item') { win.about_section.n_items == 1 }
      d.check('the about item is labelled') do
        item_attribute(win.about_section, 0, 'label') == '_About Audio Sharing'
      end
      d.check('the about item fires app.about') { item_attribute(win.about_section, 0, 'action') == 'app.about' }
    end
  end

  d.step('the menu button opens its popover') do
    app.main_window.appmenu_button.then do |button|
      button.popup
      pump(300)

      d.check('the popover is up') { button.popover.visible? }
      d.check('it drew both menu items') do
        labels(button.popover).any? { |label| label.include?('Help') } &&
          labels(button.popover).any? { |label| label.include?('About Audio Sharing') }
      end
      d.shot('03-primary-menu', button.popover)
    end
  end

  d.step('the popover closes again') do
    app.main_window.appmenu_button.then do |button|
      button.popdown
      pump(300)

      d.check('the popover is down') { !button.popover.visible? }
    end
  end

  # Gtk::Button#activate animates the press and emits `clicked` once that
  # animation is over, so the clipboard is only filled a tick later.
  d.step('the copy button is pressed') { app.main_window.copy_address_button.activate }

  d.step('the clipboard took the address and a toast says so') do
    Gdk::Display.default.clipboard.then do |clipboard|
      d.check('the clipboard has content') { !clipboard.content.nil? }
      d.check('the clipboard offers it as text') do
        clipboard.formats.mime_types.include?('text/plain;charset=utf-8')
      end
      # Gdk::ContentProvider#value trips a G_IS_VALUE assertion in these
      # bindings, so the text is read back the way a paste does it: async,
      # which means the answer lands in the next step.
      clipboard.read_text_async(nil) do |source, result|
        PASTED[:text] = source.read_text_finish(result)
      rescue StandardError => e
        PASTED[:text] = "read failed: #{e.class}: #{e.message}"
      end
    end

    app.main_window.toast_overlay.then do |overlay|
      d.check('the overlay raised the confirmation toast') do
        labels(overlay).include?('Copied address to clipboard')
      end
    end
    d.shot('04-copy-toast')
  end

  d.step('pasting gives back the address') do
    d.check('the clipboard pastes the address') { PASTED[:text] == ADDRESS }
  end

  d.step('the app installed its three actions') do
    d.check('app.help is there') { app.app.has_action?('help') }
    d.check('app.about is there') { app.app.has_action?('about') }
    d.check('app.quit is there') { app.app.has_action?('quit') }
    d.check('they are all enabled') do
      [app.help_action, app.about_action, app.quit_action].all?(&:enabled?)
    end
    # GTK parses and re-prints the accelerator, so <primary> comes back as the
    # modifier it resolves to on this platform.
    d.check('quit carries the <primary>q accelerator') do
      app.app.get_accels_for_action('app.quit') == ['<Control>q']
    end
  end

  # There is no handler for an rtsp/https url on this machine, so the launcher
  # fails — the point of the check is that app.help is wired to the launcher
  # and that the failure is caught rather than killing the app.
  d.step('app.help asks the launcher for the README url') do
    app.help_action.activate
    pump(500)

    d.check('the app survived the launch attempt') { app.main_window.window.visible? }
    d.check('the help url is upstream README') { App::HELP_URI.end_with?('/README.md') }
  end

  d.step('app.about opens the about dialog') do
    app.about_action.activate
    pump(300)

    app.main_window.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the about dialog') { dialog.is_a?(Adwaita::AboutDialog) }
      d.check('it names the app') { dialog.application_name == 'Audio Sharing' }
      d.check('it shows the application icon') { dialog.application_icon == Config::APP_ID }
      d.check('it carries the developers') { dialog.developers.size == 2 }
      d.check('it carries the designer') { dialog.designers == ['Tobias Bernard'] }
      d.check('it names the developer') { dialog.developer_name == 'Felix Häcker' }
      d.check('its version is the configured one') { dialog.version == Config.display_version }
      d.check('it is GPL-3.0') { dialog.license_type == Gtk::License::GPL_3_0 }
      d.check('it links the homepage') { dialog.website == Config::HOMEPAGE_URL }
      d.check('it links the issue tracker') { dialog.issue_url == Config::BUGTRACKER_URL }
      d.check('its comments open with the summary') do
        dialog.comments.start_with?('Share your computer audio')
      end
      d.check('it drew the Donate link') { labels(dialog).include?('Donate') }
    end
  end

  d.step('the about dialog renders') { d.shot('05-about-dialog') }

  d.step('the dialog closes again') do
    app.main_window.window.visible_dialog&.close
    pump(300)

    d.check('no dialog is up') { app.main_window.window.visible_dialog.nil? }
  end

  d.step('an error switches to the status page') do
    app.main_window.then do |win|
      win.show_error(ERROR_MESSAGE)

      d.check('the error page is showing') { win.stack.visible_child == win.error_status }
      d.check('the status page carries the message') { win.error_status.description == ERROR_MESSAGE }
      d.check('the status page keeps its title') { win.error_status.title == 'Unable to Share Audio' }
      d.check('it shows the muted icon') { win.error_status.icon_name == 'audio-volume-muted-symbolic' }
    end
  end

  d.step('the error page renders') { d.shot('06-error-page') }

  # Last, because it closes the only window and so ends the run: the shortcut
  # is pressed for real on the Xvfb display this run is already on, which is
  # the only way to know the accelerator reaches the action.
  d.step('the window takes the keyboard focus') do
    d.check('xdotool is on PATH to type with') { xdotool('--version') }
    # There is no window manager on an Xvfb display, so the focus is set
    # directly rather than by activating the window.
    xdotool(
      'search',
      '--sync',
      '--name',
      '^Audio Sharing$',
      'windowfocus',
    )
    pump(500)

    d.check('the window is the active one') { app.main_window.window.active? }
  end

  d.step('<primary>q closes the window') do
    xdotool('key', '--clearmodifiers', 'ctrl+q')
    pump(1000)

    d.check('the window closed') { !app.main_window.window.visible? }
  end
end
