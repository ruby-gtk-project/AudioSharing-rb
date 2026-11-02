# frozen_string_literal: true

require 'adwaita'

require_relative 'config'
require_relative 'gettext'
require_relative 'qrcode'
require_relative 'qrcode_paintable'

# Window is the app's only window: the QR code and address of the stream it
# shares, or a status page when there is nothing to share.
#
# Ported from upstream's src/ui/window.rs and the template it loads,
# data/gtk/window.ui: a window handle around an AdwToolbarView whose header
# bar carries the primary menu button, and whose content is a toast overlay
# over a scrolled, clamped stack of two pages — the sharing page and the
# error page.
class Window
  include Gettext

  # The window geometry data/gtk/window.ui asks for.
  DEFAULT_WIDTH = 450
  DEFAULT_HEIGHT = 500
  MINIMUM_WIDTH = 350
  MINIMUM_HEIGHT = 425

  # AdwClamp's maximum-size, and the size the QR code picture requests.
  CLAMP_WIDTH = 500
  QRCODE_SIZE = 200

  # The name of the stack's second page. The first page has none, so it is the
  # one the stack shows until something asks for this one.
  ERROR_PAGE = 'error'

  # How long the copy confirmation stays up, in seconds.
  TOAST_TIMEOUT = 2

  # The paragraph under the address, which is one msgid in the catalogues.
  INFO_TEXT = "You are currently sharing your audio. You can access it from other devices in the same network by " \
              "scanning the QR code or entering the displayed address in a playback app that supports RTSP " \
              "streams. This device can be muted, the audio will still be shared.\n" \
              "\n" \
              "To stop sharing, simply close this window."

  def initialize(app)
    @app = app
  end

  def build
    window.tap do |win|
      win.content = window_handle

      window_handle.tap do |handle|
        handle.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = toast_overlay

          header_bar.tap { |bar| bar.pack_start(appmenu_button) }

          toast_overlay.tap do |overlay|
            overlay.child = scrolled_window

            scrolled_window.tap do |scrolled|
              scrolled.child = clamp

              clamp.tap do |clamped|
                clamped.child = stack

                stack.tap do |pages|
                  pages.add_child(sharing_page)
                  pages.add_named(error_status, ERROR_PAGE)

                  sharing_page.tap do |page|
                    page.append(qrcode_picture)
                    page.append(address_box)
                    page.append(separator)
                    page.append(info_label)

                    address_box.tap do |box|
                      box.append(address_label)
                      box.append(copy_address_button)

                      copy_address_button.signal_connect('clicked') { copy_address }
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def present = window.present
  def close = window.close

  # Upstream's set_address: the address goes under the picture, and into the
  # QR code the picture shows.
  def set_address(address)
    address_label.text = address
    paintable.set_qrcode(QrCode.new(address))
    qrcode_picture.paintable = paintable.texture
  end

  # Upstream's show_error: the stack switches to the status page, which says
  # why there is nothing to share.
  def show_error(message)
    stack.visible_child_name = ERROR_PAGE
    error_status.description = message
  end

  # Memoized widget methods

  # Adwaita::ApplicationWindow, as upstream's template subclasses
  # AdwApplicationWindow: it has no titlebar of its own, which is what lets
  # the window handle and the toolbar view's header bar fill the whole window.
  # (Adwaita::Application is broken in the bindings, so the application object
  # this window belongs to stays a Gtk::Application.)
  def window
    @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
      win.title = Config::NAME
      win.icon_name = Config::APP_ID
      win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
      win.set_size_request(MINIMUM_WIDTH, MINIMUM_HEIGHT)
      win.add_css_class('audio-sharing-window')
    end
  end

  def window_handle = @window_handle ||= Gtk::WindowHandle.new
  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def stack = @stack ||= Gtk::Stack.new
  def separator = @separator ||= Gtk::Separator.new(:horizontal)
  def paintable = @paintable ||= QrCodePaintable.new

  def appmenu_button
    @appmenu_button ||= Gtk::MenuButton.new.tap do |button|
      button.has_frame = false
      button.valign = :center
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = _('Menu')
      button.primary = true
      button.menu_model = primary_menu
      button.add_css_class('circular')
    end
  end

  # The menu data/gtk/window.ui declares: two sections, the help item carrying
  # the markup that draws the arrow after its label.
  def primary_menu
    @primary_menu ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, help_section)
      menu.append_section(nil, about_section)
    end
  end

  def help_section
    @help_section ||= Gio::Menu.new.tap { |section| section.append_item(help_item) }
  end

  def help_item
    @help_item ||= Gio::MenuItem.new(_('Open _Help <sup>↗</sup>'), 'app.help').tap do |item|
      item.set_attribute_value('use-markup', GLib::Variant.new(true))
    end
  end

  def about_section
    @about_section ||= Gio::Menu.new.tap { |section| section.append(_('_About Audio Sharing'), 'app.about') }
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scrolled|
      scrolled.set_policy(:never, :automatic)
    end
  end

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |clamped|
      clamped.maximum_size = CLAMP_WIDTH
    end
  end

  # The stack's first page: everything the app shows while it is sharing.
  def sharing_page
    @sharing_page ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.halign = :center
      box.valign = :center
      box.hexpand = true
      box.vexpand = true
      box.margin_top = 12
      box.margin_bottom = 12
      box.margin_start = 12
      box.margin_end = 12
      box.add_css_class('audio-sharing')
    end
  end

  def qrcode_picture
    @qrcode_picture ||= Gtk::Picture.new.tap do |picture|
      picture.halign = :center
      picture.valign = :center
      picture.set_size_request(QRCODE_SIZE, QRCODE_SIZE)
      picture.paintable = paintable.texture
      picture.add_css_class('card')
    end
  end

  def address_box
    @address_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.halign = :center
    end
  end

  def address_label
    @address_label ||= Gtk::Label.new.tap do |label|
      label.selectable = true
      label.wrap = true
      label.justify = :center
      label.add_css_class('title-3')
    end
  end

  def copy_address_button
    @copy_address_button ||= Gtk::Button.new.tap do |button|
      button.label = _('_Copy to Clipboard')
      button.use_underline = true
      button.halign = :center
      button.add_css_class('pill')
    end
  end

  def info_label
    @info_label ||= Gtk::Label.new(_(INFO_TEXT)).tap do |label|
      label.wrap = true
      label.justify = :center
      label.add_css_class('caption')
    end
  end

  # The stack's second page, named so show_error can switch to it.
  def error_status
    @error_status ||= Adwaita::StatusPage.new.tap do |page|
      page.title = _('Unable to Share Audio')
      page.icon_name = 'audio-volume-muted-symbolic'
    end
  end

  private

    # Upstream's copy_address_button handler: the address goes to the
    # clipboard and a toast says so.
    def copy_address
      clipboard.set(address_label.text)
      toast_overlay.add_toast(copy_toast)
    end

    def copy_toast
      Adwaita::Toast.new(_('Copied address to clipboard')).tap do |toast|
        toast.timeout = TOAST_TIMEOUT
      end
    end

    def clipboard = Gdk::Display.default.clipboard
end
