// One cheap full-screen pass: distance haze and ground mist, bloom (8 taps), colour grade.
override fog_density: f32 = 0.7;
override ground_mist: f32 = 1.0;
override bloom: f32 = 0.25;
override exposure: f32 = 1.0;
override saturation: f32 = 1.2;
override contrast: f32 = 1.05;
override vignette: bool = true;

fn bright(uv: vec2<f32>) -> vec3<f32> {
    let c = textureSampleLevel(previous, linear_sampler, uv, 0.0).rgb;
    return c * smoothstep(0.8, 1.0, luminance(c));
}

fn post(input: PostInput) -> vec4<f32> {
    var c = input.color.rgb;
    let has_geo = input.depth > 0.0;
    let p = view_position(input.uv, max(input.depth, 0.000001));
    let dist = select(128.0, length(p), has_geo);

    if frame.in_water > 0.5 {
        let wc = vec3<f32>(0.02, 0.16, 0.22) * (0.25 + 0.75 * max(daylight(), 0.1));
        c = c * exp(-dist * vec3<f32>(0.22, 0.05, 0.03));
        c = mix(c, wc, 1.0 - exp(-dist * 0.08));
    } else if frame.dimension == 0 && has_geo {
        let t = dist / max(frame.fog_end, 48.0);
        let haze = 1.0 - exp(-t * 1.6 * fog_density);
        let height_fall = exp(-max(frame.camera_position.y + p.y - 64.0, 0.0) * 0.06);
        let mist_amt = ground_mist * (0.1 + 0.5 * sun_low() * daylight() + 0.8 * frame.rain);
        let mist = 1.0 - exp(-dist * 0.01 * mist_amt * height_fall);
        let total = 1.0 - (1.0 - haze) * (1.0 - mist);
        c = mix(c, vivid(frame.fog_color, 1.3), total);
    }

    if bloom > 0.0 {
        let unit = frame.resolution.y / 720.0 / frame.resolution;
        var sum = vec3<f32>(0.0);
        for (var i = 0; i < 8; i++) {
            let a = f32(i) * 0.7853982;
            sum += bright(input.uv + vec2<f32>(cos(a), sin(a)) * 7.0 * unit);
        }
        c = c + sum * (bloom / 6.0);
    }

    c = clamp(c * exposure, vec3<f32>(0.0), vec3<f32>(1.0));
    c = mix(c, c * c * (vec3<f32>(3.0) - 2.0 * c), clamp((contrast - 1.0) * 2.0, 0.0, 1.0));
    let l = luminance(c);
    c = mix(vec3<f32>(l), c, saturation);
    c = c * mix(vec3<f32>(0.97, 1.0, 1.03), vec3<f32>(1.03, 1.0, 0.96), smoothstep(0.2, 0.8, l));
    if vignette {
        let aspect = frame.resolution.x / frame.resolution.y;
        let d = length((input.uv - 0.5) * vec2<f32>(aspect, 1.0)) / length(vec2<f32>(aspect, 1.0) * 0.5);
        c = c * (1.0 - smoothstep(0.55, 1.1, d) * 0.25);
    }
    c = c + vec3<f32>((ign(input.pixel) - 0.5) * 0.008);
    return vec4<f32>(clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
