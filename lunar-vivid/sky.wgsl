// Overworld sky: vanilla's gradient made more vivid, plus a warm glow around the sun.
fn sky(input: SkyInput) -> vec4<f32> {
    if frame.dimension != 0 {
        return input.color;
    }
    var c = vivid(input.color.rgb, 1.3);
    let mu = saturate1(dot(input.direction, frame.sun_direction));
    let glow = pow(mu, 8.0) * 0.18 + pow(mu, 64.0) * 0.3;
    c = c + sun_transmittance() * (glow * daylight() * (1.0 - frame.rain));
    return vec4<f32>(clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
