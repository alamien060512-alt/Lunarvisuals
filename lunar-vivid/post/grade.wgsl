// Filmic finish: exposure, S-curve contrast, saturation, split tone, dispersion, vignette, grain.
override exposure: f32 = 1.0;
override saturation: f32 = 1.1;
override contrast: f32 = 1.1;
override vignette: bool = true;
override film_grain: f32 = 0.015;
override lens_dispersion: bool = true;

fn post(input: PostInput) -> vec4<f32> {
    var c = input.color.rgb;
    if lens_dispersion {
        let off = (input.uv - 0.5) * 0.0025;
        c.r = textureSampleLevel(previous, linear_sampler, input.uv + off, 0.0).r;
        c.b = textureSampleLevel(previous, linear_sampler, input.uv - off, 0.0).b;
    }
    c = clamp(c * exposure, vec3<f32>(0.0), vec3<f32>(1.0));
    let curve = c * c * (vec3<f32>(3.0) - 2.0 * c);
    c = mix(c, curve, clamp((contrast - 1.0) * 2.0, 0.0, 1.0));
    let l = luminance(c);
    c = mix(vec3<f32>(l), c, saturation);
    c = c * mix(vec3<f32>(0.97, 1.0, 1.03), vec3<f32>(1.03, 1.0, 0.96), smoothstep(0.2, 0.8, l));
    if vignette {
        let aspect = frame.resolution.x / frame.resolution.y;
        let d = length((input.uv - 0.5) * vec2<f32>(aspect, 1.0)) / length(vec2<f32>(aspect, 1.0) * 0.5);
        c = c * (1.0 - smoothstep(0.55, 1.1, d) * 0.28);
    }
    let noise = ign(input.pixel + vec2<f32>(f32(frame.frame_index % 64u) * 17.0, 3.0)) - 0.5;
    c = c + vec3<f32>(noise * (film_grain * (1.0 - l * 0.5) + 0.004));
    return vec4<f32>(clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
