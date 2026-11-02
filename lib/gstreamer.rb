# frozen_string_literal: true

require 'glib2'
require 'gobject-introspection'

# Gstreamer binds the two GStreamer libraries this app streams through.
#
# Ported from the `gstreamer` and `gstreamer-rtsp-server` dependencies in
# upstream's Cargo.toml, and from the `gstreamer::init()` call at the top of
# src/main.rs.
#
# ruby-gnome ships no gem for either library, but both install a typelib, so
# the loader the gobject-introspection gem exposes stands in for the two
# crates: it builds `Gst` and `GstRtspServer` at runtime out of the same
# introspection data the Rust bindings are generated from at build time.
module Gstreamer
  # The typelibs to map, in dependency order — GstRtspServer's classes carry
  # Gst types, so Gst has to be mapped first — and the constant each one is
  # mapped onto.
  NAMESPACES = {
    'Gst'           => :Gst,
    'GstRtspServer' => :GstRtspServer,
  }.freeze

  module_function

  # What `gstreamer::init()` does in src/main.rs, preceded by the binding
  # generation upstream's build does ahead of it. Calling it more than once
  # maps nothing twice.
  def init
    if @initialized.nil?
      quietly do
        NAMESPACES.each { |namespace, constant| bind(namespace, constant) }
        Gst.init([])
      end
      @initialized = true
    end
  end

  # Maps one typelib onto a fresh module and names it at the top level, so
  # `Gst::DeviceMonitor` and `GstRtspServer::RTSPServer` resolve the way the
  # ruby-gnome gems' own namespaces do.
  def bind(namespace, constant)
    Module.new.tap do |mod|
      Object.const_set(constant, mod)
      mod.const_set(:LOADER, Class.new(GObjectIntrospection::Loader).new(mod))
      mod::LOADER.load(namespace)
    end
  end

  # Runs the block with the process's standard error pointed at /dev/null.
  #
  # Mapping a whole typelib walks every signal and property in it, and the two
  # GStreamer ones carry a handful — GstBus's message signals, GstRTSPMedia's
  # handle-message — whose parameter types the introspection data does not
  # describe well enough for GObject to register. GObject complains at
  # CRITICAL about each, roughly thirty lines' worth, and then the classes are
  # built and work. Upstream never sees any of it because its bindings are
  # generated at build time rather than at startup.
  #
  # The quietening is at the file-descriptor level because GLib logs these
  # through g_log_structured, which goes straight to the structured writer and
  # so is reached by neither GLib::Log.set_handler nor anything else the glib2
  # gem exposes.
  def quietly
    $stderr.flush
    $stderr.dup.tap do |saved|
      $stderr.reopen(File::NULL, 'w')
      yield
    ensure
      $stderr.flush
      $stderr.reopen(saved)
      saved.close
    end
  end
end
