// Audio Sharing - qrcode_paintable.rs
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

// Original author: Bilal Elmoussaoui
// https://gitlab.gnome.org/bilelmoussaoui/decoder/-/blob/master/src/widgets/qrcode/paintable.rs

use std::cell::RefCell;

use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gdk, glib, graphene};

use crate::QrCode;

mod imp {
    use super::*;

    #[derive(Default)]
    pub struct QrCodePaintable {
        pub qrcode: RefCell<Option<QrCode>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for QrCodePaintable {
        const NAME: &'static str = "QrCodePaintable";
        type Type = super::QrCodePaintable;
        type Interfaces = (gdk::Paintable,);
    }

    impl ObjectImpl for QrCodePaintable {}

    impl PaintableImpl for QrCodePaintable {
        fn snapshot(&self, snapshot: &gdk::Snapshot, width: f64, height: f64) {
            let snapshot = snapshot.downcast_ref::<gtk::Snapshot>().unwrap();

            if let Some(ref qrcode) = *self.qrcode.borrow() {
                Self::snapshot_qrcode(snapshot, qrcode, width, height);
            } else {
                Self::snapshot_qrcode(snapshot, &QrCode::default(), width, height);
            }
        }
    }

    impl QrCodePaintable {
        fn snapshot_qrcode(snapshot: &gtk::Snapshot, qrcode: &QrCode, width: f64, height: f64) {
            let square_height = height as f32 / (qrcode.height() as f32 + 2.0);
            let square_width = width as f32 / (qrcode.width() as f32 + 2.0);

            snapshot.append_color(
                &gdk::RGBA::WHITE,
                &graphene::Rect::new(0.0, 0.0, width as f32, height as f32),
            );

            qrcode.items().iter().enumerate().for_each(|(y, line)| {
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
    }
}

glib::wrapper! {
    pub struct QrCodePaintable(ObjectSubclass<imp::QrCodePaintable>)
    @implements gdk::Paintable;
}

impl QrCodePaintable {
    pub fn set_qrcode(&self, qrcode: QrCode) {
        self.imp().qrcode.replace(Some(qrcode));
        self.invalidate_contents();
    }
}

impl Default for QrCodePaintable {
    fn default() -> Self {
        glib::Object::new()
    }
}
