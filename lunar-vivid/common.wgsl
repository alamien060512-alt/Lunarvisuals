// Shared helpers. Kept cheap: gamma 2.0 instead of 2.2, no per-pixel atmosphere integration.
const BETA_R: vec3<f32> = vec3<f32>(0.0058, 0.0135, 0.0331);

fn luminance(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

fn saturate1(x: f32) -> f32 {
    return clamp(x, 0.0, 1.0);
}

fn to_linear(c: vec3<f32>) -> vec3<f32> {
    return c * c;
}

fn to_display(c: vec3<f32>) -> vec3<f32> {
    return sqrt(max(c, vec3<f32>(0.0)));
}

// Extended Reinhard: soft shoulder, white point 2.5.
fn tonemap(x: vec3<f32>) -> vec3<f32> {
    return x * (vec3<f32>(1.0) + x / 6.25) / (vec3<f32>(1.0) + x);
}

fn vivid(c: vec3<f32>, amount: f32) -> vec3<f32> {
    return clamp(mix(vec3<f32>(luminance(c)), c, amount), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn daylight() -> f32 {
    return select(0.0, smoothstep(-0.1, 0.1, frame.sun_direction.y), frame.dimension == 0);
}

fn sun_low() -> f32 {
    return 1.0 - smoothstep(0.0, 0.35, abs(frame.sun_direction.y));
}

fn ign(p: vec2<f32>) -> f32 {
    return fract(52.9829189 * fract(dot(p, vec2<f32>(0.06711056, 0.00583715))));
}

// Sunlight colour after the atmosphere: white overhead, orange-red near the horizon.
fn sun_transmittance() -> vec3<f32> {
    let air = 1.0 / (max(frame.sun_direction.y, 0.0) + 0.05);
    return exp(-BETA_R * (8.0 * air));
}

// Cheap linear sky colour by height (0 horizon, 1 zenith), for ambient light and reflections.
fn sky_tint(y: f32) -> vec3<f32> {
    let day = daylight();
    var c = mix(vec3<f32>(0.30, 0.50, 0.85), vec3<f32>(0.04, 0.16, 0.50), sqrt(saturate1(y))) * day;
    c = c + vec3<f32>(0.002, 0.004, 0.012) * (1.0 - day);
    c = mix(c, vec3<f32>(0.8, 0.35, 0.15) * (1.0 - saturate1(y)), sun_low() * day * 0.5);
    return mix(c, vec3<f32>(luminance(c) * 0.7), frame.rain * 0.7);
}
