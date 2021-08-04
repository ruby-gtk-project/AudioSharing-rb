use gio::ApplicationFlags;
use glib::clone;
use glib::WeakRef;
use gstreamer::DeviceMonitor;
use gstreamer_rtsp_server::prelude::*;
use gstreamer_rtsp_server::{RTSPMediaFactory, RTSPServer};
use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gdk, gio, glib};
use gtk_macros::action;
use log::{debug, info, warn};
use once_cell::sync::OnceCell;
use pnet::datalink::interfaces;

use crate::config;
use crate::ui::about_dialog;
use crate::ui::AsApplicationWindow;

mod imp {
    use super::*;

    #[derive(Debug, Default)]
    pub struct AsApplication {
        pub window: OnceCell<WeakRef<AsApplicationWindow>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for AsApplication {
        const NAME: &'static str = "AsApplication";
        type Type = super::AsApplication;
        type ParentType = gtk::Application;
    }

    impl ObjectImpl for AsApplication {}

    impl gio::subclass::prelude::ApplicationImpl for AsApplication {
        fn activate(&self, app: &Self::Type) {
            debug!("GtkApplication<AsApplication>::activate");

            let priv_ = AsApplication::from_instance(app);
            if let Some(window) = priv_.window.get() {
                let window = window.upgrade().unwrap();
                window.show();
                window.present();
            }
        }

        fn startup(&self, app: &Self::Type) {
            debug!("GtkApplication<AsApplication>::startup");
            self.parent_startup(app);

            app.setup_css();

            let window = AsApplicationWindow::new(app);
            self.window
                .set(window.downgrade())
                .expect("Window already set.");

            app.get_main_window().present();

            app.setup_gactions();
            app.setup_accels();
            app.setup_server();
        }
    }

    impl GtkApplicationImpl for AsApplication {}
}

glib::wrapper! {
    pub struct AsApplication(ObjectSubclass<imp::AsApplication>)
        @extends gio::Application, gtk::Application, @implements gio::ActionMap, gio::ActionGroup;
}

impl AsApplication {
    pub fn new() -> Self {
        glib::Object::new(&[
            ("application-id", &Some(config::APP_ID)),
            ("flags", &ApplicationFlags::empty()),
            (
                "resource-base-path",
                &Some("/de/haeckerfelix/AudioSharing/"),
            ),
        ])
        .expect("Application initialization failed...")
    }

    fn get_main_window(&self) -> AsApplicationWindow {
        let priv_ = imp::AsApplication::from_instance(self);
        priv_.window.get().unwrap().upgrade().unwrap()
    }

    fn setup_gactions(&self) {
        // Quit
        action!(
            self,
            "quit",
            clone!(@weak self as app => move |_, _| {
                app.quit();
            })
        );

        // Help
        action!(
            self,
            "help",
            clone!(@weak self as app => move |_, _| {
                gtk::show_uri(Some(&app.get_main_window()), "https://gitlab.gnome.org/World/AudioSharing/-/blob/master/README.md", gdk::CURRENT_TIME);
            })
        );

        // About
        action!(
            self,
            "about",
            clone!(@weak self as app => move |_, _| {
                about_dialog::show_about_dialog(&app.get_main_window());
            })
        );
    }

    // Sets up keyboard shortcuts
    fn setup_accels(&self) {
        self.set_accels_for_action("app.quit", &["<primary>q"]);
        self.set_accels_for_action("win.show-help-overlay", &["<primary>question"]);
    }

    fn setup_css(&self) {
        let provider = gtk::CssProvider::new();
        provider.load_from_resource("/de/haeckerfelix/AudioSharing/gtk/style.css");
        if let Some(display) = gdk::Display::default() {
            gtk::StyleContext::add_provider_for_display(
                &display,
                &provider,
                gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
            );
        }
    }

    fn setup_server(&self) {
        if let Some(device) = self.find_device_name() {
            // Setup and start RTSP server
            let server = RTSPServer::new();

            let factory = RTSPMediaFactory::new();
            let launch = format!(
                "pulsesrc device={} client-name=audio-share ! vorbisenc ! rtpvorbispay name=pay0 pt=96",
                device
            );
            factory.set_launch(&launch);
            factory.set_shared(true);

            let mounts = server.mount_points().unwrap();
            mounts.add_factory("/audio", &factory);

            let ctx = glib::MainContext::default();
            server.attach(Some(&ctx)).unwrap();

            let ip = self.get_ip_addr();
            let address = format!("rtsp://{}:8554/audio", ip);
            self.get_main_window().set_address(address);
        } else {
            warn!("Unable to find audio sink");
            self.get_main_window()
                .show_error("No audio sink found".into());
        }
    }

    fn get_ip_addr(&self) -> String {
        // Get a vector with all network interfaces found
        let all_interfaces = interfaces();

        // Search for the default interface - the one that is
        // up, not loopback and has an IP.
        let default_interface = all_interfaces.iter().find(|e| {
            e.is_up() && !e.is_loopback() && !e.ips.is_empty() && !e.name.contains("virbr")
        });

        if let Some(interface) = default_interface {
            info!("Using network interface {:?}", interface);
            let ip = interface.ips.get(0).unwrap().ip();
            return ip.to_string();
        }

        "0.0.0.0".into()
    }

    fn find_device_name(&self) -> Option<String> {
        // Use gstreamer device monitor to find out the sink which we want to stream
        let device_monitor = DeviceMonitor::new();
        device_monitor
            .start()
            .expect("Unable to start gstreamer device monitor");

        let mut device_name = None;

        for device in &device_monitor.devices() {
            let is_sink = device.device_class() == "Audio/Sink";
            let is_default = device.properties()?.get::<bool>("is-default").ok()?;
            let node_name = device.properties()?.get::<String>("node.name").ok()?;

            if is_sink && is_default {
                info!("Using {} as device.", device.display_name());
                device_name = Some(node_name);
            }
        }

        device_monitor.stop();
        device_name
    }

    pub fn run(&self) {
        info!("Audio Sharing ({})", config::APP_ID);
        info!("Version: {} ({})", config::VERSION, config::PROFILE);
        info!("Datadir: {}", config::PKGDATADIR);

        ApplicationExtManual::run(self);
    }
}
