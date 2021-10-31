# Audio Sharing

<img src="data/screenshots/1.png"/>

Running Audio Sharing will automatically share the current audio playback in the form of an RTSP stream. This stream can then be played back by other devices, for example using VLC. 

#### Why this app, and not just using Bluetooth?
By sharing the audio as a network stream, you can also use common devices that are not intended to be used as audio sinks (eg. smartphones) to receive it. 

For example, there are audio accessories that are not compatible with desktop computers (e.g. because the computer does not have a Bluetooth module installed). With the help of this app, the computer audio can be played back on a smartphone, which is then connected to the Bluetooth accessory.

#### How I can receive the audio stream?

For playback, you need a program that can play RTSP streams.

VLC is supported, and is available for smartphones and computers. 
- [VLC for Android](https://play.google.com/store/apps/details?id=org.videolan.vlc)
- [VLC for iOS](https://apps.apple.com/app/apple-store/id650377962)
- [VLC for desktop](https://flathub.org/apps/details/org.videolan.VLC)

#### I can receive the stream, but there's a noticeable delay
There is usually a setting in the playback program where you can adjust the latency / caching. If this value is reduced, the latency/delay should be noticeably better.

For example for the VLC iOS app: 
 1. Open iOS Settings
 2. Click on VLC
 3. Network cache level -> lowest latency

You have to test a bit with the values to find the perfect balance between latency and audio quality. Unfortunately, latency cannot be completely prevented, but depending on the use case, it may not be an issue (e.g. listening to music).

## Installation
The recommended way of installing Audio Sharing is using the Flatpak package. If you don't have Flatpak installed yet, you can get it from [here](https://flatpak.org/setup/).

`flatpak install https://flathub.org/repo/appstream/de.haeckerfelix.AudioSharing.flatpakref`

<a href="https://flathub.org/apps/details/de.haeckerfelix.AudioSharing"><img src="https://flathub.org/assets/badges/flathub-badge-en.png" width="200"/></a>

## Building
Audio Sharing can be built and run with [GNOME Builder](https://wiki.gnome.org/Apps/Builder) >= 3.28.
Just clone the repo and hit the run button. You can get Builder from [here](https://wiki.gnome.org/Apps/Builder/Downloads).

## Code Of Conduct
We follow the [GNOME Code of Conduct](/CODE_OF_CONDUCT.md).
All communications in project spaces are expected to follow it.

## Credits
- [Decoder](https://gitlab.gnome.org/bilelmoussaoui/decoder) for the QR code widget
- [Typography](https://gitlab.gnome.org/World/design/typography) for the window styling
