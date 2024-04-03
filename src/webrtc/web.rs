// Audio Sharing - web.rs
// Copyright (C) 2024  Felix Häcker <haeckerfelix@gnome.org>
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

use actix_web::{get, web, App, Error, HttpRequest, HttpResponse, HttpServer};
use actix_web_static_files::ResourceFiles;

include!(concat!(env!("OUT_DIR"), "/generated.rs"));

#[get("/webrtc")]
async fn proxy(req: HttpRequest, stream: web::Payload) -> Result<HttpResponse, Error> {
    info!("Proxying request");
    actix_ws_proxy::start(&req, "ws://127.0.0.1:8443".into(), stream).await
}

#[actix_web::main]
pub async fn spawn() -> Result<(), std::io::Error> {
    info!("Start web server");
    HttpServer::new(|| {
        let generated = generate();
        App::new()
            .service(proxy)
            .service(ResourceFiles::new("/", generated))
    })
    .bind(("0.0.0.0", 9090))?
    .run()
    .await
}
