// Shared helpers: colour space, a small analytic atmosphere, tonemapping, noise.
const PI: f32 = 3.14159265;
// Rayleigh scattering coefficients (relative), red to blue.
const BETA_R: vec3<f32> = vec3<f32>(0.0058, 0.0135, 0.0331);

fn luminance(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

fn saturate1(x: f32) -> f32 {
    return clamp(x, 0.0, 1.0);
}

fn to_linear(c: vec3<f32>) -> vec3<f32> {
    return pow(max(c, vec3<f32>(0.0)), vec3<f32>(2.2));
}

fn to_display(c: vec3<f32>) -> vec3<f32> {
    return pow(max(c, vec3<f32>(0.0)), vec3<f32>(1.0 / 2.2));
}

// Extended Reinhard: soft shoulder, white point 2.5.
fn tonemap(x: vec3<f32>) -> vec3<f32> {
    return x * (vec3<f32>(1.0) + x / 6.25) / (vec3<f32>(1.0) + x);
}

// 1 while the sun is up in the Overworld.
fn daylight() -> f32 {
    return select(0.0, smoothstep(-0.1, 0.1, frame.sun_direction.y), frame.dimension == 0);
}

// 1 when the sun is on the horizon, 0 from about a third of the way up.
fn sun_low() -> f32 {
    return 1.0 - smoothstep(0.0, 0.35, abs(frame.sun_direction.y));
}

// Interleaved gradient noise, good for per-pixel dither.
fn ign(p: vec2<f32>) -> f32 {
    return fract(52.9829189 * fract(dot(p, vec2<f32>(0.06711056, 0.00583715))));
}

// Henyey-Greenstein phase function.
fn hg(mu: f32, g: f32) -> f32 {
    let g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}

// Sunlight colour after crossing the atmosphere: white overhead, orange to red near the horizon.
fn sun_transmittance() -> vec3<f32> {
    let air = 1.0 / (max(frame.sun_direction.y, 0.0) + 0.05);
    return exp(-BETA_R * (8.0 * air));
}

// Linear HDR sky radiance along a unit direction (Rayleigh + Mie single scattering, twilight, night).
fn atmosphere(dir: vec3<f32>) -> vec3<f32> {
    let d = normalize(dir);
    let sy = frame.sun_direction.y;
    let mu = dot(d, frame.sun_direction);
    let air = 1.0 / (max(d.y, 0.0) + 0.07);
    let ext = BETA_R * (8.0 * air);
    let sun_t = sun_transmittance();
    let sun_up = smoothstep(-0.18, 0.08, sy);

    let rayleigh = (vec3<f32>(1.0) - exp(-ext)) * sun_t * (0.75 * (1.0 + mu * mu));
    let mie = sun_t * (hg(mu, 0.78) * 0.35 * (1.0 - exp(-air * 0.35)));
    var col = (rayleigh * 5.0 + mie * 2.0) * sun_up;

    // Twilight: a warm band hugging the horizon on the sun's side, violet above it.
    let twi = smoothstep(-0.30, -0.05, sy) * (1.0 - smoothstep(-0.05, 0.12, sy));
    let side = 0.25 + 0.75 * pow(saturate1(mu * 0.5 + 0.5), 3.0);
    col += vec3<f32>(0.9, 0.38, 0.22) * (twi * side * exp(-max(d.y, 0.0) * 5.0) * 0.6);
    col += vec3<f32>(0.12, 0.16, 0.35) * (twi * 0.15);

    // Night: faint blue sky and a halo around the moon.
    let moon_halo = pow(saturate1(dot(d, frame.moon_direction)), 12.0) * smoothstep(-0.1, 0.2, frame.moon_direction.y);
    col += (vec3<f32>(0.004, 0.007, 0.016) + vec3<f32>(0.02, 0.03, 0.05) * moon_halo) * (1.0 - sun_up);
    return col;
}

// Display-referred sky colour (weather applied), for the sky stage and for haze that must match it.
fn sky_display(dir: vec3<f32>) -> vec3<f32> {
    var c = atmosphere(dir);
    c = mix(c, vec3<f32>(luminance(c) * 0.7), frame.rain * 0.7);
    c = c * (1.0 - frame.thunder * 0.35);
    let mapped = to_display(vec3<f32>(1.0) - exp(-c));
    return clamp(mix(vec3<f32>(luminance(mapped)), mapped, 1.25), vec3<f32>(0.0), vec3<f32>(1.0));
}
