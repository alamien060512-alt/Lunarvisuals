# Lunar Realism

A realism-focused shader pack for [Horizon](https://github.com/horizon-rust/horizon) (shader API 0.1, WGSL).

| Stage | What it does |
| --- | --- |
| `sky` | Analytic Rayleigh + Mie atmosphere, sunrise/sunset colour, twilight, moonlit night, weather. |
| `material` | Sun/moon shadow map (5-tap PCF), warm sun and cool sky light, torch light, wet sheen. Water: waves, fresnel reflections (mirror texture), refraction, depth absorption, shore foam, sun glints. |
| post 1 | Screen-space ambient occlusion |
| post 2 | Aerial haze matched to the sky, ground mist, underwater fog |
| post 3 | God rays |
| post 4 | Bloom |
| post 5 | Filmic grade: contrast, saturation, split tone, lens dispersion, vignette, grain |

## Install

```
cargo run -p horizon-shader-api --bin horizon-shader -- check lunar-realism
cargo run -p horizon-shader-api --bin horizon-shader -- pack lunar-realism
```

Copy the folder (or the resulting `.hshader`) into `shaderpacks/`, then choose it under
Options > Horizon Settings > Shader Packs. All settings are exposed as options.

## Status

Written against `docs/api/shaders-reference.md`. Not yet run through `horizon-shader check`
or in game, so expect tuning (brightness balance, GPU budget). If the sun or god rays look
mirrored, the projection's y convention differs from the one assumed in `post/godrays.wgsl`.
