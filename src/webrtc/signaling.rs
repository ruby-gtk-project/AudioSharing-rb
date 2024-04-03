// Audio Sharing - signaling.rs
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

// SPDX-License-Identifier: MPL-2.0

use anyhow::Error;
use gst_plugin_webrtc_signalling::handlers::Handler;
use gst_plugin_webrtc_signalling::server::Server;
use tokio::net::TcpListener;
use tokio::task;

#[tokio::main]
pub async fn spawn() -> Result<(), Error> {
    let server = Server::spawn(Handler::new);
    let addr = "0.0.0.0:8443";

    let listener = TcpListener::bind(&addr).await?;

    info!("Listening on: {}", addr);

    while let Ok((stream, address)) = listener.accept().await {
        let mut server_clone = server.clone();
        info!("Accepting connection from {}", address);
        task::spawn(async move { server_clone.accept_async(stream).await });
    }

    Ok(())
}
