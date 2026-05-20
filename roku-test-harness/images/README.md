# images/ — required channel artwork (placeholders)

This directory must contain real PNG assets before the channel is packaged. The
`manifest` references the filenames below by `pkg:/images/...` path. They cannot
be generated meaningfully in this environment, so supply your own PNGs at the
listed pixel dimensions.

| Filename             | Manifest key            | Required size (px) | Purpose                         |
| -------------------- | ----------------------- | ------------------ | ------------------------------- |
| `icon_focus_hd.png`  | `mm_icon_focus_hd`      | 290 x 218          | HD channel icon, focused        |
| `icon_focus_sd.png`  | `mm_icon_focus_sd`      | 246 x 140          | SD channel icon, focused        |
| `icon_side_hd.png`   | `mm_icon_side_hd`       | 108 x 69           | HD channel icon, side menu      |
| `icon_side_sd.png`   | `mm_icon_side_sd`       | 80 x 58            | SD channel icon, side menu      |
| `splash_hd.png`      | `splash_screen_hd`      | 1280 x 720         | HD splash screen                |
| `splash_sd.png`      | `splash_screen_sd`      | 720 x 480          | SD splash screen                |
| `splash_fhd.png`     | `splash_screen_fhd`     | 1920 x 1080        | FHD splash screen               |

Notes:
- All files must be 24-bit (or 32-bit with alpha) PNGs.
- The `Poster` and `field type="uri"` references in `components/SpecShowcase.xml`
  reuse `icon_focus_hd.png`; if that asset is missing the Poster simply renders
  empty — it does not break the channel or the tests.
- Packaging will succeed without these files, but the launcher tile and splash
  will be blank until real assets are added.
