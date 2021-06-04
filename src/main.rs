// Audio Sharing - main.rs
// Copyright (C) 2021  Felix Häcker <haeckerfelix@gnome.org>
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

extern crate pretty_env_logger;

use gettextrs::*;
use std::env;

mod ui;

mod app;
mod config;
mod i18n;
mod qrcode;

pub use crate::app::AsApplication;
pub use crate::qrcode::QRCode;

use gtk::{gio, glib};

fn main() {
    // Initialize logger
    pretty_env_logger::init();

    // Initialize GTK
    gtk::init().unwrap_or_else(|_| panic!("Failed to initialize GTK."));
    adw::init();

    // Initialize Gstreamer
    gstreamer::init().expect("Failed to initialize Gstreamer");

    // Initialize variables
    glib::set_application_name(config::NAME);
    glib::set_prgname(Some(&config::APP_ID));
    gtk::Window::set_default_icon_name(config::APP_ID);
    env::set_var("PULSE_PROP_application.icon_name", config::APP_ID);
    env::set_var("PULSE_PROP_application.metadata().name", config::NAME);

    // Setup translations
    setlocale(LocaleCategory::LcAll, "").unwrap();
    bindtextdomain(config::PKGNAME, config::LOCALEDIR).unwrap();
    textdomain(config::PKGNAME).unwrap();

    // Load app resources
    let res = gio::Resource::load(
        config::PKGDATADIR.to_owned() + &format!("/{}.gresource", config::APP_ID),
    )
    .expect("Could not load resources");
    gio::resources_register(&res);

    // Run app itself
    let app = AsApplication::new();
    app.run();
}
