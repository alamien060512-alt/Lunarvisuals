// Screen-space ambient occlusion: 12 depth taps on a rotated spiral, view-space hemisphere test.
override ao_strength: f32 = 0.8;
override ao_radius: f32 = 1.4;

fn post(input: PostInput) -> vec4<f32> {
    if ao_strength <= 0.0 || input.depth == 0.0 {
        return input.color;
    }
    let p = view_position(input.uv, input.depth);
    let dist = length(p);
    let px = 1.0 / frame.resolution;
    let uv_r = input.uv + vec2<f32>(px.x, 0.0);
    let uv_u = input.uv - vec2<f32>(0.0, px.y);
    let pr = view_position(uv_r, depth_at(uv_r));
    let pu = view_position(uv_u, depth_at(uv_u));
    var n = normalize(cross(pr - p, pu - p));
    if dot(n, p) > 0.0 {
        n = -n;
    }
    let smooth_ok = max(length(pr - p), length(pu - p)) < 0.15 * dist + 1.0;
    n = select(normalize(-p), n, smooth_ok);

    let aspect_inv = frame.resolution.y / frame.resolution.x;
    let radius_uv = clamp(ao_radius * frame.projection[1][1] * 0.5 / max(dist, 0.5), 0.003, 0.12);
    let rot = ign(input.pixel + vec2<f32>(f32(frame.frame_index % 8u) * 5.588238)) * 6.2831853;

    var occ = 0.0;
    for (var i = 0; i < 12; i++) {
        let fi = f32(i);
        let a = fi * 2.3999632 + rot;
        let r = sqrt((fi + 0.5) / 12.0);
        let suv = input.uv + vec2<f32>(cos(a) * aspect_inv, sin(a)) * (r * radius_uv);
        let sd = depth_at(suv);
        let q = view_position(suv, sd);
        let v = q - p;
        let len = length(v) + 0.0001;
        let cosine = max(dot(v, n) - 0.05, 0.0) / len;
        let falloff = 1.0 - smoothstep(ao_radius, ao_radius * 2.5, len);
        occ += cosine * falloff * select(0.0, 1.0, sd > 0.0);
    }
    let ao = clamp(1.0 - (occ / 12.0) * ao_strength * 1.6, 0.0, 1.0);
    return vec4<f32>(input.color.rgb * mix(1.0, ao, 0.9), input.color.a);
}
