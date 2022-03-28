// Original author: Bilal Elmoussaoui
// https://gitlab.gnome.org/bilelmoussaoui/decoder/-/blob/master/src/widgets/qrcode/paintable.rs

use crate::qrcode::QRCodeData;
use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gdk, glib, graphene};
use once_cell::sync::Lazy;

static INIT_QR_CODE: Lazy<QRCodeData> = Lazy::new(|| QRCodeData::from("0.0.0.0"));

mod imp {

    fn snapshot_qrcode(snapshot: &gtk::Snapshot, qrcode: &QRCodeData, width: f64, height: f64) {
        let manager = adw::StyleManager::default();
        let is_dark_theme = manager.is_dark();

        // If theme is dark we draw a white background and leave a one-tile margin around it
        let square_height =
            height as f32 / (qrcode.height as f32 + (is_dark_theme as i32 * 2) as f32);
        let square_width = width as f32 / (qrcode.width as f32 + (is_dark_theme as i32 * 2) as f32);

        if is_dark_theme {
            snapshot.append_color(
                &gdk::RGBA::WHITE,
                &graphene::Rect::new(0.0, 0.0, width as f32, height as f32),
            );
        }

        qrcode.items.iter().enumerate().for_each(|(y, line)| {
            line.iter().enumerate().for_each(|(x, is_dark)| {
                let color = if *is_dark {
                    gdk::RGBA::BLACK
                } else {
                    gdk::RGBA::new(0.0, 0.0, 0.0, 0.0)
                };
                let position = graphene::Rect::new(
                    (x + is_dark_theme as usize) as f32 * square_width,
                    (y + is_dark_theme as usize) as f32 * square_height,
                    square_width,
                    square_height,
                );

                snapshot.append_color(&color, &position);
            });
        });
    }
    use super::*;
    use std::cell::RefCell;
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
        fn snapshot(
            &self,
            _paintable: &Self::Type,
            snapshot: &gdk::Snapshot,
            width: f64,
            height: f64,
        ) {
            let snapshot = snapshot.downcast_ref::<gtk::Snapshot>().unwrap();

            if let Some(ref qrcode) = *self.qrcode.borrow() {
                snapshot_qrcode(snapshot, qrcode, width, height);
            } else {
                snapshot_qrcode(snapshot, &*INIT_QR_CODE, width, height);
            }
        }
    }
}

glib::wrapper! {
    pub struct QRCodePaintable(ObjectSubclass<imp::QRCodePaintable>) @implements gdk::Paintable;
}

impl QRCodePaintable {
    pub fn set_qrcode(&self, qrcode: QRCodeData) {
        let self_ = imp::QRCodePaintable::from_instance(self);
        self_.qrcode.replace(Some(qrcode));
        self.invalidate_contents();
    }
}

impl Default for QRCodePaintable {
    fn default() -> Self {
        glib::Object::new(&[]).expect("Failed to create a QRCodePaintable")
    }
}
