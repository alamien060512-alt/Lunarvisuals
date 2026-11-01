// Bloom from bright pixels: two rings of eight taps, sized relative to the picture height.
override bloom: f32 = 0.35;

fn bright(uv: vec2<f32>) -> vec3<f32> {
    let c = textureSampleLevel(previous, linear_sampler, uv, 0.0).rgb;
    return c * smoothstep(0.7, 1.0, luminance(c));
}

fn post(input: PostInput) -> vec4<f32> {
    if bloom <= 0.0 {
        return input.color;
    }
    let unit = frame.resolution.y / 720.0 / frame.resolution;
    var sum = vec3<f32>(0.0);
    for (var i = 0; i < 8; i++) {
        let a = f32(i) * 0.7853982;
        let d = vec2<f32>(cos(a), sin(a));
        sum += bright(input.uv + d * 4.0 * unit) * 0.6;
        sum += bright(input.uv + d * 12.0 * unit) * 0.4;
    }
    return vec4<f32>(input.color.rgb + sum * (bloom / 6.0), input.color.a);
}
