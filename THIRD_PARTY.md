# Third-party code

bastian-shell is licensed under **GPL-3.0-or-later** (see [LICENSE](LICENSE)).
Some files contain code adapted from other projects. Each of them keeps an origin header naming the source.

| Files | Source | License |
|---|---|---|
| `shell/services/Hypr.qml` (event list) | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | GPL-3.0 |
| `equicord/desktopBridge/*` (plugin for Equicord) | [Equicord](https://github.com/Equicord/Equicord) plugin API; camera/screen-share calls after its plugins ToggleVideoBind and InstantScreenshare | GPL-3.0-or-later |
| `shell/modules/switcher/Switcher.qml` | KDE KWin | GPL-2.0-or-later |
| `plasma/loginscreen/components/*`, layout of `shell/modules/lock/Lock.qml` | KDE Plasma Workspace | GPL-2.0-or-later / LGPL-2.0-or-later |
| `theme/gen/icons.py` (derived icon theme, mirrors Breeze) | KDE Breeze Icons | LGPL-3.0 |
| `theme/gen/kvantum.py`, `theme/out/kvantum/DesktopHearth/` (recolored theme) | KvFlat by Tsu Jan ([Kvantum](https://github.com/tsujan/Kvantum)) | GPL-3.0 |
| `theme/gen/chrome-ext/autofill.js`, `theme/gen/chrome-ext/popup.js` | [Sank6/iCloud-Keychain-for-Linux](https://github.com/Sank6/iCloud-Keychain-for-Linux) | MIT (text below) |

All of these licenses are compatible with GPL-3.0-or-later.

## MIT License (Sank6/iCloud-Keychain-for-Linux)

```
MIT License

Copyright (c) 2026 Sankarsh Makam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
