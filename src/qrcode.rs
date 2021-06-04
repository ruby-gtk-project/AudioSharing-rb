// Original author: Bilal Elmoussaoui
// https://gitlab.gnome.org/bilelmoussaoui/decoder/-/raw/master/src/qrcode.rs

use glib::ParamSpec;
use gtk::glib;
use gtk::prelude::*;
use gtk::subclass::prelude::*;
pub use imp::QRCodeData;
use once_cell::sync::Lazy;

mod imp {
    use super::*;
    use std::cell::{Cell, RefCell};

    #[derive(Debug, Clone, glib::GBoxed)]
    #[gboxed(type_name = "QRCodeData")]
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
                .quiet_zone(false)
                .module_dimensions(1, 1)
                .build()
                .split('\n')
                .into_iter()
                .map(|line| {
                    line.chars()
                        .into_iter()
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

    #[derive(Debug)]
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

        fn new() -> Self {
            Self {
                id: Cell::new(0),
                content: RefCell::new("".to_string()),
                data: RefCell::new(None),
            }
        }
    }

    impl ObjectImpl for QRCode {
        fn properties() -> &'static [ParamSpec] {
            static PROPERTIES: Lazy<Vec<ParamSpec>> = Lazy::new(|| {
                vec![
                    ParamSpec::new_int(
                        "id",
                        "id",
                        "Id",
                        0,
                        i32::MAX,
                        0,
                        glib::ParamFlags::READWRITE | glib::ParamFlags::CONSTRUCT_ONLY,
                    ),
                    ParamSpec::new_string(
                        "content",
                        "content",
                        "Content",
                        None,
                        glib::ParamFlags::READWRITE,
                    ),
                ]
            });
            PROPERTIES.as_ref()
        }

        fn set_property(
            &self,
            _obj: &Self::Type,
            _id: usize,
            value: &glib::Value,
            pspec: &ParamSpec,
        ) {
            match pspec.name() {
                "id" => {
                    self.id.replace(value.get::<i32>().unwrap());
                }
                "content" => {
                    let content = value.get::<String>().unwrap();
                    self.content.replace(content);
                }
                _ => unimplemented!(),
            }
        }

        fn property(&self, _obj: &Self::Type, _id: usize, pspec: &ParamSpec) -> glib::Value {
            match pspec.name() {
                "id" => self.id.get().to_value(),
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
    pub fn new(id: i32, content: String) -> Self {
        let qr_code: QRCode = glib::Object::new(&[("id", &id), ("content", &content)])
            .expect("Failed to create a QRCode object");
        let self_ = imp::QRCode::from_instance(&qr_code);
        let qrcode_data = imp::QRCodeData::from(content.as_str());
        self_.data.replace(Some(qrcode_data));
        qr_code
    }

    pub fn id(&self) -> i32 {
        let self_ = imp::QRCode::from_instance(self);
        self_.id.get()
    }

    pub fn content(&self) -> String {
        let self_ = imp::QRCode::from_instance(self);
        self_.content.borrow().clone()
    }

    pub fn data(&self) -> QRCodeData {
        let self_ = imp::QRCode::from_instance(self);
        self_.data.borrow().as_ref().unwrap().clone()
    }
}
