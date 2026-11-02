# frozen_string_literal: true

require 'adwaita'

require_relative 'config'
require_relative 'gettext'
require_relative 'about_dialog'
require_relative 'rtsp_server'
require_relative 'window'

# App is the application object.
#
# Ported from upstream's src/main.rs — the process-wide setup it does before
# the application exists — and from src/app.rs, whose `activate` creates the
# window, presents it, adds the three application actions the primary menu
# and the quit accelerator use, and then starts the RTSP server.
class App
  include Gettext

  # The url src/app.rs hands to the UriLauncher for app.help.
  HELP_URI = 'https://gitlab.gnome.org/World/AudioSharing/-/blob/main/README.md'

  # The accelerator src/app.rs sets for app.quit.
  QUIT_ACCELS = ['<primary>q'].freeze

  def build
    app.tap do |application|
      application.signal_connect('activate') do
        actions
        main_window.present
        rtsp_server.start
      end
    end
  end

  def run = app.run([])

  # Adwaita::Application is broken in the Ruby bindings, so the application
  # object is a Gtk::Application and only the window is Adwaita's.
  def app
    @app ||= begin
      Adwaita.init
      configure_process
      Gtk::Application.new(Config::APP_ID, :default_flags)
    end
  end

  # The one window, built the first time it is asked for. A second activation
  # presents this window again rather than building another, which is what
  # upstream's stored window weak reference is for.
  def main_window = @main_window ||= Window.new(app).tap { |win| win.build }

  # Upstream's setup_server, which runs at the end of activate: the server
  # either comes up and hands the window the address to show, or finds no sink
  # to record and the window shows that instead.
  def rtsp_server
    @rtsp_server ||= RtspServer.new(
      app,
      on_address: ->(address) { main_window.set_address(address) },
      on_error:   ->(message) { main_window.show_error(message) },
    )
  end

  # app.help, app.about and app.quit, added once.
  def actions
    @actions ||= [help_action, about_action, quit_action].each { |action| app.add_action(action) }
  end

  def help_action
    @help_action ||= Gio::SimpleAction.new('help', nil).tap do |action|
      action.signal_connect('activate') { open_help }
    end
  end

  def about_action
    @about_action ||= Gio::SimpleAction.new('about', nil).tap do |action|
      action.signal_connect('activate') { show_about }
    end
  end

  def quit_action
    @quit_action ||= Gio::SimpleAction.new('quit', nil).tap do |action|
      action.signal_connect('activate') { main_window.close }
      app.set_accels_for_action('app.quit', QUIT_ACCELS)
    end
  end

  private

    # What src/main.rs sets up before running the app: the name GLib reports
    # for this process, the icon its windows take by default, and the two
    # PulseAudio properties that give the audio stream this app's name and
    # icon.
    def configure_process
      GLib.application_name = Config::NAME
      Gtk::Window.set_default_icon_name(Config::APP_ID)
      ENV['PULSE_PROP_application.icon_name'] = Config::APP_ID
      ENV['PULSE_PROP_application.metadata().name'] = Config::NAME
    end

    # Upstream logs whatever the launch future returns and carries on. The
    # Ruby bindings raise the GError as a Gtk::DialogError — which is a
    # StandardError but not a GLib::Error — and an exception raised inside an
    # async callback takes the whole process down with it, so the rescue has
    # to be as wide as upstream's `if let Err(err)`.
    def open_help
      Gtk::UriLauncher.new(HELP_URI).launch(main_window.window, nil) do |launcher, result|
        launcher.launch_finish(result)
      rescue StandardError => e
        warn "Could not open url: #{e.message}"
      end
    end

    def show_about
      AboutDialog.new.tap do |dialog|
        dialog.build
        dialog.present(main_window.window)
      end
    end
end
