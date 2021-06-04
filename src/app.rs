use gio::ApplicationFlags;
use glib::clone;
use glib::WeakRef;
use gstreamer_rtsp_server::prelude::*;
use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gdk, gio, glib};
use gtk_macros::action;
use log::{debug, info};
use once_cell::sync::OnceCell;

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
                return;
            }

            app.set_resource_base_path(Some("/de/haeckerfelix/AudioSharing/"));
            app.setup_css();

            let window = AsApplicationWindow::new(app);
            self.window
                .set(window.downgrade())
                .expect("Window already set.");

            app.setup_gactions();
            app.setup_accels();
            app.setup_server();

            app.get_main_window().present();
        }

        fn startup(&self, app: &Self::Type) {
            debug!("GtkApplication<AsApplication>::startup");
            self.parent_startup(app);
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
                // This is needed to trigger the delete event
                // and saving the window state
                app.get_main_window().close();
                app.quit();
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
        let server = gstreamer_rtsp_server::RTSPServer::new();
        dbg!(server.address());

        let mounts = server.mount_points().unwrap();

        let factory = gstreamer_rtsp_server::RTSPMediaFactory::new();
        dbg!(factory.latency());

        factory.set_launch("pulsesrc device=alsa_output.pci-0000_06_00.6.HiFi__hw_Generic_1__sink ! vorbisenc ! rtpvorbispay name=pay0 pt=96");
        factory.set_shared(true);

        //factory.create_element();

        mounts.add_factory("/test", &factory);

        server.connect_client_connected(|_, _| {
            debug!("Client connected");
        });

        let ctx = glib::MainContext::default();
        server.attach(Some(&ctx)).unwrap();

        self.get_main_window().set_address("Works!".to_string());
    }

    pub fn run(&self) {
        info!("Audio Sharing ({})", config::APP_ID);
        info!("Version: {} ({})", config::VERSION, config::PROFILE);
        info!("Datadir: {}", config::PKGDATADIR);

        ApplicationExtManual::run(self);
    }
}
