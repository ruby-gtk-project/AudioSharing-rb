# frozen_string_literal: true

require 'socket'

require_relative 'gettext'
require_relative 'gstreamer'

# RtspServer shares this machine's audio output over RTSP.
#
# Ported from upstream's src/app.rs — setup_server, find_device_name and
# get_ip_addr, plus the client-connected handler that raises the
# audio-sharing-playback notification.
#
# The shape is upstream's: find the default audio sink, hang a media factory
# that records its monitor source off /audio, attach the server to the main
# context, and hand the resulting address back to whoever asked. When there is
# no sink to record, nothing is started and the error is reported instead.
class RtspServer
  include Gettext

  # The port GstRTSPServer listens on by default, and the path upstream mounts
  # the factory at. Both appear in the address the window shows, so they are
  # named rather than spelled into the format string twice.
  SERVICE_PORT = 8554
  MOUNT_POINT = '/audio'

  # What get_ip_addr falls back to when no interface qualifies.
  FALLBACK_ADDRESS = '0.0.0.0'

  # Upstream skips libvirt's bridges when picking an interface: they are up and
  # carry an address, but it is one no other device on the network can reach.
  VIRTUAL_BRIDGE = 'virbr'

  # The GStreamer pipeline upstream hands the media factory. pulsesrc records
  # the sink's monitor source, which is the audio this machine is playing, and
  # the payloader has to be called pay0 for GstRTSPMediaFactory to find it.
  LAUNCH = 'pulsesrc device=%<node_name>s.monitor client-name=audio-sharing ! ' \
           'vorbisenc ! rtpvorbispay name=pay0 pt=96'

  # The gstreamer device class and property that mark the sink to record.
  SINK_CLASS = 'Audio/Sink'
  DEFAULT_PROPERTY = 'is-default'

  # The property a pulse device's element carries its PulseAudio node name on.
  NODE_NAME_PROPERTY = 'device'

  # What upstream shows when find_device_name comes back empty. Untranslated,
  # as it is upstream.
  NO_SINK_MESSAGE = 'No audio sink found'

  # The id upstream gives the notification, so a second connection replaces the
  # first one's banner rather than stacking another beside it.
  NOTIFICATION_ID = 'audio-sharing-playback'

  # @param app [Gtk::Application] the application the notification is sent
  #   through, which is what upstream's `gio::Application::default()` reaches.
  # @param on_address [Proc] called with the rtsp:// address once the server is
  #   listening — upstream's `window.set_address(address)`.
  # @param on_error [Proc] called with a message when there is nothing to
  #   share — upstream's `window.show_error(...)`.
  def initialize(app, on_address: nil, on_error: nil)
    @app = app
    @on_address = on_address
    @on_error = on_error
  end

  attr_reader :app, :on_address, :on_error

  # Upstream's setup_server. Either the server is started and the address
  # reported, or the error is.
  def start
    device_name.then do |name|
      if name.nil?
        on_error&.call(NO_SINK_MESSAGE)
      else
        share
      end
    end
  end

  # The address the window shows and the QR code encodes.
  def address = "rtsp://#{ip_address}:#{SERVICE_PORT}#{MOUNT_POINT}"

  # Upstream's get_ip_addr: the first interface that is up, is not loopback, is
  # not a libvirt bridge and has an address, reduced to the first of its
  # addresses.
  def ip_address
    interface_addresses.find { |_name, addresses| !addresses.empty? }.then do |interface|
      if interface.nil?
        FALLBACK_ADDRESS
      else
        interface.last.first
      end
    end
  end

  # Upstream's find_device_name: the PulseAudio node name of the default audio
  # sink, or nil when the device monitor lists none.
  def device_name
    @device_name ||= find_device_name
  end

  private

    # Upstream's find_device_name, called once: the answer is what the launch
    # line is built from and what decides whether anything is started at all.
    def find_device_name
      Gstreamer.init
      Gst::DeviceMonitor.new.then do |monitor|
        monitor.start
        monitor.devices.find { |device| default_sink?(device) }.then do |device|
          monitor.stop
          if device.nil?
            nil
          else
            node_name_of(device)
          end
        end
      end
    end

    # Starts the server and reports the address it is reachable at.
    def share
      server.tap do |rtsp|
        rtsp.mount_points.add_factory(MOUNT_POINT, media_factory)
        rtsp.attach(GLib::MainContext.default)
      end
      on_address&.call(address)
    end

    def server
      @server ||= GstRtspServer::RTSPServer.new.tap do |rtsp|
        rtsp.signal_connect('client-connected') { notify_playback }
      end
    end

    def media_factory
      @media_factory ||= GstRtspServer::RTSPMediaFactory.new.tap do |factory|
        factory.launch = format(LAUNCH, node_name: device_name)
        # Shared, so a second listener joins the stream the first one started
        # rather than opening a second recording of the same sink.
        factory.shared = true
      end
    end

    # Upstream's client-connected handler: a banner saying the audio of this
    # machine is now going somewhere else.
    def notify_playback
      app.send_notification(NOTIFICATION_ID, notification)
    end

    def notification
      @notification ||= Gio::Notification.new(_('A client has established a connection')).tap do |note|
        note.body = _('Audio playback from this device gets shared.')
      end
    end

    # A device is the one to record when the monitor calls it an audio sink and
    # its properties say it is the default one.
    def default_sink?(device)
      device.device_class == SINK_CLASS && default?(device.properties)
    end

    # Gst::Structure#get_boolean answers with the pair [found, value], so a
    # structure without the field reads as false rather than as nil.
    def default?(properties)
      if properties.nil?
        false
      else
        properties.get_boolean(DEFAULT_PROPERTY).last
      end
    end

    # The node name lives on the element the device creates, not on the device.
    def node_name_of(device)
      device.create_element(nil).then do |element|
        if element.nil?
          nil
        else
          element.get_property(NODE_NAME_PROPERTY)
        end
      end
    end

    # The interfaces upstream's `pnet::datalink::interfaces()` would hand it,
    # in the same order and with the same ones dropped: name => its addresses.
    # An interface that is up but has no address keeps an empty list, so it is
    # passed over exactly the way upstream's `!e.ips.is_empty()` passes it.
    def interface_addresses
      Socket.getifaddrs.each_with_object({}) do |ifaddr, found|
        if shareable?(ifaddr)
          found[ifaddr.name] = (found[ifaddr.name] || []) + addresses_of(ifaddr)
        end
      end
    end

    def shareable?(ifaddr)
      ifaddr.flags.anybits?(Socket::IFF_UP) &&
        ifaddr.flags.nobits?(Socket::IFF_LOOPBACK) &&
        !ifaddr.name.include?(VIRTUAL_BRIDGE)
    end

    # One getifaddrs entry carries at most one address, and entries that carry
    # a link-layer one instead carry none this can use.
    def addresses_of(ifaddr)
      ifaddr.addr.then do |addr|
        if addr.nil? || !addr.ip?
          []
        else
          [addr.ip_address]
        end
      end
    end
end
