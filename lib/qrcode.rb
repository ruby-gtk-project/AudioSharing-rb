# frozen_string_literal: true

require 'rqrcode_core'

# QrCode encodes a string as the module matrix of a QR code.
#
# Ported from upstream's src/qrcode.rs, a GObject wrapper around the Rust
# `qrcode` crate: it encodes the content bytes at error correction level M and
# renders them with a four module quiet zone, exposing the result as `items`
# (rows of booleans, true where the module is dark) plus its `width` and
# `height`. There is no libqrencode/qrcode binding for Ruby, so the encoding
# comes from `rqrcode_core` (pure Ruby) instead — the same substitution the
# pilot (`gnome-contacts-rb/lib/qr_code_dialog.rb`) makes.
class QrCode
  # The light border the matrix is rendered with, in modules. The crate's
  # `quiet_zone(true)` is this; `rqrcode_core` does not add one itself, so it
  # is added here.
  QUIET_ZONE = 4

  attr_reader :content

  def initialize(content)
    @content = content.to_s
  end

  # The module matrix with its quiet zone, as rows of booleans.
  def items = @items ||= with_quiet_zone(encoded.modules)

  def width = items.first.size
  def height = items.size

  private

    def encoded = @encoded ||= RQRCodeCore::QRCode.new(content, level: :m, mode: :byte_8bit)

    def with_quiet_zone(rows)
      border = Array.new(QUIET_ZONE, false)
      blank = Array.new(QUIET_ZONE) { Array.new(rows.first.size + (QUIET_ZONE * 2), false) }
      blank + rows.map { |row| border + row + border } + blank
    end
end
