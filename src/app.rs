// Audio Sharing - app.rs
// Copyright (C) 2022-2024  Felix Häcker <haeckerfelix@gnome.org>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

use std::cell::OnceCell;

use adw::subclass::prelude::*;
use glib::{clone, WeakRef};
use gstreamer::prelude::*;
use gstreamer::DeviceMonitor;
use gtk::prelude::*;
use gtk::{gio, glib};
use pnet::datalink::interfaces;

use crate::config;
use crate::ui::{about_dialog, AsApplicationWindow};
use crate::webrtc::{signaling, web};

mod imp {
    use super::*;

    #[derive(Debug, Default)]
    pub struct AsApplication {
        window: OnceCell<WeakRef<AsApplicationWindow>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for AsApplication {
        const NAME: &'static str = "AsApplication";
        type Type = super::AsApplication;
        type ParentType = adw::Application;
    }

    impl ObjectImpl for AsApplication {}

    impl ApplicationImpl for AsApplication {
        fn activate(&self) {
            debug!("Activate GIO Application...");
            let obj = self.obj();

            // If the window already exists,
            // present it instead creating a new one again.
            if let Some(weak_win) = self.window.get() {
                let window = weak_win.upgrade().unwrap();
                window.present();
                info!("Application window presented.");
                return;
            }

            // No window available -> we have to create one
            let window = AsApplicationWindow::new(&self.obj());
            let _ = self.window.set(window.downgrade());
            window.present();
            info!("Created application window.");

            // Setup GActions

            // app.help
            let action = gio::SimpleAction::new("help", None);
            action.connect_activate(clone!(@weak window, @weak obj => move |_, _| {
                let launcher = gtk::UriLauncher::new("https://gitlab.gnome.org/World/AudioSharing/-/blob/main/README.md");
                launcher.launch(Some(&window), gio::Cancellable::NONE, move |result| {
                    if let Err(err) = result {
                        error!("Could not open url: {err}");
                    }
                });
            }));
            obj.add_action(&action);

            // app.about
            let action = gio::SimpleAction::new("about", None);
            action.connect_activate(clone!(@weak window => move |_, _| {
                about_dialog::show(&window);
            }));
            obj.add_action(&action);

            // app.quit
            let action = gio::SimpleAction::new("quit", None);
            action.connect_activate(clone!(@weak window => move |_, _| {
                window.close();
            }));
            obj.set_accels_for_action("app.quit", &["<primary>q"]);
            obj.add_action(&action);

            // Start webrtc machinery
            std::thread::spawn(move || {
                info!("start signaling");
                signaling::spawn().unwrap();
            });

            std::thread::spawn(move || {
                info!("start web");
                web::spawn().unwrap();
            });

            self.setup_server(&window);
        }
    }

    impl GtkApplicationImpl for AsApplication {}

    impl AdwApplicationImpl for AsApplication {}

    impl AsApplication {
        fn setup_server(&self, window: &AsApplicationWindow) {
            gstrswebrtc::plugin_register_static().unwrap();

            if let Some(node_name) = self.find_device_name() {
                // for pipewire
                // node.target
                let launch = format!(
                    "webrtcsink name=ws meta=\"meta,name=AudioSharing\" pulsesrc device={}.monitor client-name=audio-sharing ! ws.",
                    //"webrtcsink name=ws meta=\"meta,name=gst-stream\" pipewiresrc path=51 ! ws.",
                    node_name
                );

                let element = gstreamer::parse::launch(&launch).unwrap();
                let pipeline = element.downcast::<gstreamer::Pipeline>().unwrap();

                pipeline.set_state(gstreamer::State::Playing).unwrap();

                let ip = self.get_ip_addr();
                let address = format!("http://{}:9090", ip);
                window.set_address(address);
            } else {
                warn!("Unable to find audio sink");
                window.show_error("No audio sink found".into());
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
                let ip = interface.ips.first().unwrap().ip();
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

            for device in device_monitor.devices() {
                let is_sink = device.device_class() == "Audio/Sink";
                let is_default = device.properties()?.get::<bool>("is-default").ok();

                if is_sink && is_default == Some(true) {
                    let element = device.create_element(None).ok()?;
                    let node_name = element.property::<Option<String>>("device")?;
                    info!(
                        "Using \"{}\" as device ({}).",
                        device.display_name(),
                        node_name
                    );

                    device_monitor.stop();
                    return Some(node_name);
                }
            }

            device_monitor.stop();
            None
        }
    }
}

glib::wrapper! {
    pub struct AsApplication(ObjectSubclass<imp::AsApplication>)
        @extends gio::Application, gtk::Application, adw::Application,
        @implements gio::ActionMap, gio::ActionGroup;
}

impl AsApplication {
    pub fn run() -> glib::ExitCode {
        debug!(
            "{} ({}) ({}) - Version {} ({})",
            config::NAME,
            config::APP_ID,
            config::VCS_TAG,
            config::VERSION,
            config::PROFILE
        );

        // Create new GObject and downcast it into AsApplication
        let app = glib::Object::builder::<AsApplication>()
            .property("application-id", config::APP_ID)
            .property("resource-base-path", config::PATH_ID)
            .build();

        // Start running gtk::Application
        app.run()
    }
}

impl Default for AsApplication {
    fn default() -> Self {
        gio::Application::default()
            .expect("Could not get default GApplication")
            .downcast()
            .unwrap()
    }
}
