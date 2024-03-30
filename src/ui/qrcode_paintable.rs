// Original author: Bilal Elmoussaoui
// https://gitlab.gnome.org/bilelmoussaoui/decoder/-/blob/master/src/widgets/qrcode/paintable.rs

use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gdk, glib, graphene};
use once_cell::sync::Lazy;

use crate::qrcode::QRCodeData;

static INIT_QR_CODE: Lazy<QRCodeData> = Lazy::new(|| QRCodeData::from("0.0.0.0"));

mod imp {

    fn snapshot_qrcode(snapshot: &gtk::Snapshot, qrcode: &QRCodeData, width: f64, height: f64) {
        let square_height = height as f32 / (qrcode.height as f32 + 2.0);
        let square_width = width as f32 / (qrcode.width as f32 + 2.0);

        snapshot.append_color(
            &gdk::RGBA::WHITE,
            &graphene::Rect::new(0.0, 0.0, width as f32, height as f32),
        );

        qrcode.items.iter().enumerate().for_each(|(y, line)| {
            line.iter().enumerate().for_each(|(x, is_dark)| {
                let color = if *is_dark {
                    gdk::RGBA::BLACK
                } else {
                    gdk::RGBA::new(0.0, 0.0, 0.0, 0.0)
                };
                let position = graphene::Rect::new(
                    (x + 1) as f32 * square_width,
                    (y + 1) as f32 * square_height,
                    square_width,
                    square_height,
                );

                snapshot.append_color(&color, &position);
            });
        });
    }
    use std::cell::RefCell;

    use super::*;
    pub struct QRCodePaintable {
        pub qrcode: RefCell<Option<QRCodeData>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for QRCodePaintable {
        const NAME: &'static str = "QRCodePaintable";
        type Type = super::QRCodePaintable;
        type ParentType = glib::Object;
        type Interfaces = (gdk::Paintable,);

        fn new() -> Self {
            Self {
                qrcode: RefCell::new(None),
            }
        }
    }

    impl ObjectImpl for QRCodePaintable {}

    impl PaintableImpl for QRCodePaintable {
        fn snapshot(&self, snapshot: &gdk::Snapshot, width: f64, height: f64) {
            let snapshot = snapshot.downcast_ref::<gtk::Snapshot>().unwrap();

            if let Some(ref qrcode) = *self.qrcode.borrow() {
                snapshot_qrcode(snapshot, qrcode, width, height);
            } else {
                snapshot_qrcode(snapshot, &INIT_QR_CODE, width, height);
            }
        }
    }
}

glib::wrapper! {
    pub struct QRCodePaintable(ObjectSubclass<imp::QRCodePaintable>) @implements gdk::Paintable;
}

impl QRCodePaintable {
    pub fn set_qrcode(&self, qrcode: QRCodeData) {
        self.imp().qrcode.replace(Some(qrcode));
        self.invalidate_contents();
    }
}

impl Default for QRCodePaintable {
    fn default() -> Self {
        glib::Object::new()
    }
}
