// Screen-space crepuscular rays: march toward the sun, gathering bright sky not blocked by terrain.
override god_rays: f32 = 0.5;

fn post(input: PostInput) -> vec4<f32> {
    if god_rays <= 0.0 || daylight() <= 0.0 {
        return input.color;
    }
    let clip = frame.projection * (frame.view * vec4<f32>(frame.sun_direction, 0.0));
    if clip.w <= 0.0 {
        return input.color;
    }
    let ndc = clip.xy / clip.w;
    let sun_uv = vec2<f32>(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
    let delta = sun_uv - input.uv;
    let jitter = ign(input.pixel + vec2<f32>(f32(frame.frame_index % 8u) * 5.588238));

    var acc = 0.0;
    for (var i = 0; i < 16; i++) {
        let t = (f32(i) + jitter) / 16.0;
        let suv = input.uv + delta * (t * 0.8);
        let is_sky = select(0.0, 1.0, depth_at(suv) == 0.0);
        let c = textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
        acc += is_sky * smoothstep(0.7, 1.0, luminance(c)) * pow(0.94, f32(i));
    }
    let aspect = frame.resolution.x / frame.resolution.y;
    let to_sun = length(delta * vec2<f32>(aspect, 1.0));
    let fade = 1.0 - smoothstep(0.0, 1.4, to_sun);
    let tint = mix(vec3<f32>(1.0, 0.95, 0.85), vec3<f32>(1.0, 0.6, 0.3), sun_low());
    let rays = tint * (acc / 16.0 * god_rays * daylight() * (1.0 - frame.rain) * fade * 0.9);
    return vec4<f32>(input.color.rgb + rays, input.color.a);
}
