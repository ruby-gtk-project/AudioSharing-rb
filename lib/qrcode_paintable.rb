# frozen_string_literal: true

require 'adwaita'
require 'cairo'
require 'stringio'

require_relative 'qrcode'

# QrCodePaintable draws a QrCode for the window's picture.
#
# Ported from upstream's src/ui/qrcode_paintable.rs: a GdkPaintable whose
# snapshot paints its whole area white and then one square per module, dark
# modules black and light ones transparent, the matrix inset by one module on
# every side. Until a code is set it paints the empty one, which is what
# upstream's `QrCode::default()` fallback does.
#
# The Ruby bindings cannot give GTK a GdkPaintable written in Ruby — a
# Gtk::Picture refuses the object, since the interface's snapshot is never
# dispatched back into Ruby — so the same drawing is done with Cairo and
# handed over as a Gdk::Texture, which is a paintable GTK does accept.
class QrCodePaintable
  # The side of one painted module, in pixels. The picture is 200 pixels wide
  # and scales whatever texture it is given, so this only decides how much
  # detail there is to scale from.
  MODULE_SIZE = 10

  # The one module inset upstream's snapshot leaves around the matrix, on top
  # of the quiet zone the matrix already carries.
  PADDING = 1

  attr_reader :qrcode

  def initialize(qrcode = QrCode.new(''))
    @qrcode = qrcode
  end

  # Upstream's set_qrcode, which replaces the code and invalidates what was
  # drawn from the old one.
  def set_qrcode(qrcode)
    @qrcode = qrcode
    @texture = nil
  end

  # The paintable itself, drawn once per code.
  def texture = @texture ||= Gdk::Texture.new(GLib::Bytes.new(png))

  private

    def png
      Cairo::ImageSurface.new(:rgb24, pixel_width, pixel_height).then do |surface|
        Cairo::Context.new(surface).tap { |context| paint(context) }
        StringIO.new.tap { |io| surface.write_to_png(io) }.string
      end
    end

    def paint(context)
      context.set_source_rgb(1, 1, 1)
      context.paint
      context.set_source_rgb(0, 0, 0)
      qrcode.items.each_with_index do |row, y|
        row.each_with_index do |dark, x|
          if dark
            paint_module(context, x, y)
          end
        end
      end
      context.fill
    end

    def paint_module(context, x, y)
      context.rectangle(
        (x + PADDING) * MODULE_SIZE,
        (y + PADDING) * MODULE_SIZE,
        MODULE_SIZE,
        MODULE_SIZE,
      )
    end

    def pixel_width = (qrcode.width + (PADDING * 2)) * MODULE_SIZE
    def pixel_height = (qrcode.height + (PADDING * 2)) * MODULE_SIZE
end
