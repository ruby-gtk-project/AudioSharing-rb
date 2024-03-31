// Audio Sharing - qrcode.rs
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
// https://gitlab.gnome.org/bilelmoussaoui/decoder/-/raw/master/src/qrcode.rs

use std::cell::{Cell, OnceCell, RefCell};

use gtk::glib;
use gtk::glib::Properties;
use gtk::prelude::*;
use gtk::subclass::prelude::*;

mod imp {
    use super::*;

    #[derive(Debug, Properties, Default)]
    #[properties(wrapper_type = super::QrCode)]
    pub struct QrCode {
        #[property(get, set, construct_only)]
        content: OnceCell<String>,
        #[property(get)]
        width: Cell<i32>,
        #[property(get)]
        height: Cell<i32>,

        pub items: RefCell<Vec<Vec<bool>>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for QrCode {
        const NAME: &'static str = "QrCode";
        type Type = super::QrCode;
    }

    #[glib::derived_properties]
    impl ObjectImpl for QrCode {
        fn constructed(&self) {
            self.parent_constructed();

            let code = qrcode::QrCode::new(self.obj().content().as_bytes()).unwrap();
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
            let width = items.first().unwrap().len() as i32;
            let height = items.len() as i32;

            self.width.set(width);
            self.height.set(height);
            self.items.replace(items);
        }
    }
}

glib::wrapper! {
    pub struct QrCode(ObjectSubclass<imp::QrCode>);
}

impl QrCode {
    pub fn new(content: &str) -> Self {
        glib::Object::builder().property("content", content).build()
    }

    pub fn items(&self) -> Vec<Vec<bool>> {
        self.imp().items.borrow().clone()
    }
}

impl Default for QrCode {
    fn default() -> Self {
        QrCode::new("")
    }
}
