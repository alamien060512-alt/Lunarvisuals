// Overworld sky from an analytic atmosphere. Other dimensions keep vanilla's colour.
fn sky(input: SkyInput) -> vec4<f32> {
    if frame.dimension != 0 {
        return input.color;
    }
    var c = sky_display(input.direction);
    let below = 1.0 - smoothstep(-0.4, 0.0, input.direction.y);
    c = c * (1.0 - below * 0.25);
    return vec4<f32>(c, input.color.a);
}
