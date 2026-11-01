# Lunar Vivid

An original shader pack for [Horizon](https://github.com/horizon-rust/horizon) (shader API 0.1, WGSL).
It aims for the same general style as ComplementaryReimagined by Complementary Development
(https://github.com/ComplementaryDevelopment/ComplementaryReimagined): vibrant colour, warm sun against cool
shadows, bright water, soft haze and bloom. It is inspired by that look only. It contains no code or
assets from it, and it is not affiliated with Complementary Development.

Stages: atmospheric sky, shadowed terrain lighting and stylized water, then post passes for ambient
occlusion, haze, god rays, bloom and colour grade. Every setting is an in-game option.

Check and package with `horizon-shader check lunar-vivid` and `horizon-shader pack lunar-vivid`,
then put the folder or `.hshader` in `shaderpacks/`.

Status: not yet run through `horizon-shader check` or in game. Expect tuning.
