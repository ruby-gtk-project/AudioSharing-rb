// Audio Sharing - window.rs
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

use adw::subclass::prelude::*;
use glib::clone;
use gtk::prelude::*;
use gtk::{self, gdk, gio, glib, CompositeTemplate};

use crate::app::AsApplication;
use crate::i18n::i18n;
use crate::ui::QrCodePaintable;
use crate::QrCode;

mod imp {
    use super::*;

    #[derive(Default, Debug, CompositeTemplate)]
    #[template(resource = "/de/haeckerfelix/AudioSharing/gtk/window.ui")]
    pub struct AsApplicationWindow {
        #[template_child]
        toast_overlay: TemplateChild<adw::ToastOverlay>,
        #[template_child]
        pub qrcode: TemplateChild<gtk::Picture>,
        #[template_child]
        pub address_label: TemplateChild<gtk::Label>,
        #[template_child]
        copy_address_button: TemplateChild<gtk::Button>,
        #[template_child]
        pub stack: TemplateChild<gtk::Stack>,
        #[template_child]
        pub error_status: TemplateChild<adw::StatusPage>,

        pub paintable: QrCodePaintable,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for AsApplicationWindow {
        const NAME: &'static str = "AsApplicationWindow";
        type Type = super::AsApplicationWindow;
        type ParentType = adw::ApplicationWindow;

        fn class_init(klass: &mut Self::Class) {
            Self::bind_template(klass);
        }

        fn instance_init(obj: &glib::subclass::InitializingObject<Self>) {
            obj.init_template();
        }
    }

    impl ObjectImpl for AsApplicationWindow {
        fn constructed(&self) {
            self.parent_constructed();

            self.copy_address_button
                .connect_clicked(clone!(@weak self as this => move|_|
                    let address = this.address_label.get().text();

                    let display = gdk::Display::default().unwrap();
                    let clipboard = display.clipboard();
                    clipboard.set_text(&address);

                    let toast = adw::Toast::new(&i18n("Copied address to clipboard"));
                    toast.set_timeout(2);
                    this.toast_overlay.add_toast(toast);
                ));
        }
    }

    impl WidgetImpl for AsApplicationWindow {}

    impl WindowImpl for AsApplicationWindow {}

    impl ApplicationWindowImpl for AsApplicationWindow {}

    impl AdwApplicationWindowImpl for AsApplicationWindow {}
}

glib::wrapper! {
    pub struct AsApplicationWindow(ObjectSubclass<imp::AsApplicationWindow>)
        @extends gtk::Widget, gtk::Window, gtk::ApplicationWindow, adw::ApplicationWindow,
        @implements gio::ActionMap, gio::ActionGroup;
}

impl AsApplicationWindow {
    pub fn new(app: &AsApplication) -> Self {
        glib::Object::builder::<AsApplicationWindow>()
            .property("application", app)
            .build()
    }

    pub fn set_address(&self, address: String) {
        let qr = QrCode::new(&address);

        let imp = self.imp();
        imp.address_label.set_text(&address);
        imp.paintable.set_qrcode(qr);
        imp.qrcode.set_paintable(Some(&imp.paintable));
    }

    pub fn show_error(&self, message: String) {
        let imp = self.imp();

        imp.stack.set_visible_child_name("error");
        imp.error_status.set_description(Some(&message));
    }
}
