// Original author: Bilal Elmoussaoui
// https://gitlab.gnome.org/bilelmoussaoui/decoder/-/raw/master/src/qrcode.rs

use glib::{ParamSpec, ParamSpecString};
use gtk::glib;
use gtk::prelude::*;
use gtk::subclass::prelude::*;
pub use imp::QRCodeData;
use once_cell::sync::Lazy;

mod imp {
    use std::cell::{Cell, RefCell};

    use super::*;

    #[derive(Debug, Clone, glib::Boxed)]
    #[boxed_type(name = "QRCodeData")]
    pub struct QRCodeData {
        pub width: i32,
        pub height: i32,
        pub items: Vec<Vec<bool>>,
    }

    impl From<&str> for QRCodeData {
        fn from(data: &str) -> Self {
            let code = qrcode::QrCode::new(data.as_bytes()).unwrap();
            let items = code
                .render::<char>()
                .quiet_zone(true)
                .module_dimensions(1, 1)
                .build()
                .split('\n')
                .map(|line| {
                    line.chars()
                        .map(|c| !c.is_whitespace())
                        .collect::<Vec<bool>>()
                })
                .collect::<Vec<Vec<bool>>>();

            let width = items.get(0).unwrap().len() as i32;
            let height = items.len() as i32;
            Self {
                width,
                height,
                items,
            }
        }
    }

    #[derive(Debug, Default)]
    pub struct QRCode {
        pub id: Cell<i32>,
        pub content: RefCell<String>,
        pub data: RefCell<Option<QRCodeData>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for QRCode {
        const NAME: &'static str = "QRCode";
        type ParentType = glib::Object;
        type Type = super::QRCode;
    }

    impl ObjectImpl for QRCode {
        fn properties() -> &'static [ParamSpec] {
            static PROPERTIES: Lazy<Vec<ParamSpec>> =
                Lazy::new(|| vec![ParamSpecString::builder("content").readwrite().build()]);
            PROPERTIES.as_ref()
        }

        fn set_property(&self, _id: usize, value: &glib::Value, pspec: &ParamSpec) {
            match pspec.name() {
                "content" => {
                    let content = value.get::<String>().unwrap();
                    self.content.replace(content);
                }
                _ => unimplemented!(),
            }
        }

        fn property(&self, _id: usize, pspec: &ParamSpec) -> glib::Value {
            match pspec.name() {
                "content" => self.content.borrow().to_value(),
                _ => unimplemented!(),
            }
        }
    }
}

glib::wrapper! {
    pub struct QRCode(ObjectSubclass<imp::QRCode>);
}

impl QRCode {
    pub fn new(content: String) -> Self {
        let qr_code: QRCode = glib::Object::builder()
            .property("content", &content)
            .build();
        let qrcode_data = imp::QRCodeData::from(content.as_str());
        qr_code.imp().data.replace(Some(qrcode_data));
        qr_code
    }

    pub fn content(&self) -> String {
        self.imp().content.borrow().clone()
    }

    pub fn data(&self) -> QRCodeData {
        self.imp().data.borrow().as_ref().unwrap().clone()
    }
}
