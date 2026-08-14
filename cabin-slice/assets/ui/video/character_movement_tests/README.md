# Character movement video tests

Generated motion-reference clips for validating the protagonist movement standard before producing the full direction set.

## Naming

`heroNN_<action>_<screen-direction>_<background>_<version>.mp4`

- `se`: character faces screen-down-right.
- `green`: chroma-green background test.
- `white_high`: white-background test with a higher isometric camera angle.

## Current clips

| File | Resolution / rate | Purpose |
| --- | --- | --- |
| `hero01_glasses/hero01_run_se_green_v01.mp4` | 1280x720, 24 fps, ~4 s | Initial movement and identity test; green background contains lighting variation and a soft ground shadow. |
| `hero01_glasses/hero01_run_se_white_high_v02.mp4` | 1280x720, 24 fps, ~4 s | Revised higher-angle test on white; still contains a subtle gray floor gradient and soft shadow. |

These are review assets, not final seamless gameplay loops. Before runtime use, approve the camera/action standard, normalize the background, remove shadows, select an exact cycle interval, and verify root lock and first/last-frame continuity.
