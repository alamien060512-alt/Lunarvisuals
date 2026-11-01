// Aerial perspective toward the atmosphere's own horizon colour, ground mist, and underwater fog.
override fog_density: f32 = 1.0;
override ground_mist: f32 = 1.0;

fn post(input: PostInput) -> vec4<f32> {
    var c = input.color.rgb;
    let has_geo = input.depth > 0.0;
    let p = view_position(input.uv, max(input.depth, 0.000001));
    let dist = select(128.0, length(p), has_geo);
    let dir = normalize(p);

    if frame.in_water > 0.5 {
        let wc = vec3<f32>(0.02, 0.16, 0.22) * (0.25 + 0.75 * max(daylight(), 0.1));
        c = c * exp(-dist * vec3<f32>(0.22, 0.05, 0.03));
        c = mix(c, wc, 1.0 - exp(-dist * 0.08));
        return vec4<f32>(c, input.color.a);
    }
    if frame.dimension != 0 || !has_geo {
        return vec4<f32>(c, input.color.a);
    }

    let fog_dir = normalize(vec3<f32>(dir.x, clamp(dir.y, 0.0, 0.15), dir.z));
    let fog_col = sky_display(fog_dir);

    let t = dist / max(frame.fog_end, 48.0);
    let haze = 1.0 - exp(-t * 3.0 * clamp(fog_density, 0.0, 1.5));

    let world_y = frame.camera_position.y + p.y;
    let height_fall = exp(-max(world_y - 64.0, 0.0) * 0.06);
    let mist_amt = ground_mist * (0.15 + 0.7 * sun_low() * daylight() + 0.8 * frame.rain);
    let mist = 1.0 - exp(-dist * 0.012 * mist_amt * height_fall);

    let total = 1.0 - (1.0 - haze) * (1.0 - mist);
    c = mix(c, fog_col, total);
    return vec4<f32>(c, input.color.a);
}
