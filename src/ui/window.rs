use glib::clone;
use gtk::subclass::prelude::*;
use gtk::{self, prelude::*};
use gtk::{gdk, gio, glib, CompositeTemplate};

use crate::app::AsApplication;
use crate::config::APP_ID;
use crate::i18n::i18n;
use crate::ui::QRCodePaintable;
use crate::QRCode;

mod imp {
    use super::*;

    #[derive(Default, Debug, CompositeTemplate)]
    #[template(resource = "/de/haeckerfelix/AudioSharing/gtk/window.ui")]
    pub struct AsApplicationWindow {
        #[template_child]
        pub toast_overlay: TemplateChild<adw::ToastOverlay>,
        #[template_child]
        pub qrcode: TemplateChild<gtk::Picture>,
        #[template_child]
        pub address_label: TemplateChild<gtk::Label>,
        #[template_child]
        pub copy_address_button: TemplateChild<gtk::Button>,
        #[template_child]
        pub stack: TemplateChild<gtk::Stack>,
        #[template_child]
        pub error_status: TemplateChild<adw::StatusPage>,

        pub paintable: QRCodePaintable,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for AsApplicationWindow {
        const NAME: &'static str = "AsApplicationWindow";
        type Type = super::AsApplicationWindow;
        type ParentType = gtk::ApplicationWindow;

        fn class_init(klass: &mut Self::Class) {
            Self::bind_template(klass);
        }

        fn instance_init(obj: &glib::subclass::InitializingObject<Self>) {
            obj.init_template();
        }
    }

    impl ObjectImpl for AsApplicationWindow {}
    impl WidgetImpl for AsApplicationWindow {}
    impl WindowImpl for AsApplicationWindow {}
    impl ApplicationWindowImpl for AsApplicationWindow {}
}

glib::wrapper! {
    pub struct AsApplicationWindow(ObjectSubclass<imp::AsApplicationWindow>)
        @extends gtk::Widget, gtk::Window, gtk::ApplicationWindow, @implements gio::ActionMap, gio::ActionGroup;
}

impl AsApplicationWindow {
    pub fn new(app: &AsApplication) -> Self {
        let window: Self = glib::Object::new(&[("application", app)]).unwrap();

        // Set icons for shell
        gtk::Window::set_default_icon_name(APP_ID);

        window.setup_widgets();
        window
    }

    fn setup_widgets(&self) {
        let imp = self.imp();

        imp.copy_address_button
            .connect_clicked(clone!(@weak self as this => move|_|
                let imp = this.imp();
                let address = imp.address_label.get().text();

                let display = gdk::Display::default().unwrap();
                let clipboard = display.clipboard();
                clipboard.set_text(&address.to_string());

                let toast = adw::Toast::new(&i18n("Copied address to clipboard"));
                toast.set_timeout(2);
                imp.toast_overlay.add_toast(&toast);
            ));
    }

    pub fn set_address(&self, address: String) {
        let imp = self.imp();

        imp.address_label.set_text(&address);
        let qr = QRCode::new(address);
        imp.paintable.set_qrcode(qr.data());
        imp.qrcode.set_paintable(Some(&imp.paintable));
    }

    pub fn show_error(&self, message: String) {
        let imp = self.imp();

        imp.stack.set_visible_child_name("error");
        imp.error_status.set_description(Some(&message));
    }
}
