// Terrain lighting: sun/moon with shadow-map shadows, sky and torch light, wet surfaces,
// and water with waves, fresnel reflections, refraction, depth absorption and shore foam.
override sun_strength: f32 = 1.0;
override ambient_strength: f32 = 1.0;
override block_light: f32 = 1.0;
override water_waves: f32 = 1.0;
override water_clarity: f32 = 0.5;
override water_reflections: bool = true;

struct Lit {
    direct: vec3<f32>,
    indirect: vec3<f32>,
    vis: f32,
}

fn sun_color() -> vec3<f32> {
    let day = smoothstep(-0.05, 0.12, frame.sun_direction.y);
    let moon = smoothstep(-0.05, 0.15, frame.moon_direction.y) * (1.0 - day);
    return sun_transmittance() * (1.3 * day) + vec3<f32>(0.28, 0.40, 0.72) * (0.05 * moon);
}

// Direction toward the light that is up: the sun by day, the moon by night.
fn light_dir() -> vec3<f32> {
    return select(frame.moon_direction, frame.sun_direction, frame.sun_direction.y > -0.05);
}

fn lighting(n: vec3<f32>, pos: vec3<f32>, light: vec2<f32>) -> Lit {
    let l = light_dir();
    let ndl = dot(n, l);
    let diff = clamp((ndl + 0.1) / 1.1, 0.0, 1.0);
    let sky_gate = smoothstep(0.45, 0.92, light.y);
    let vis = 1.0;
    let rain_dim = 1.0 - frame.rain * 0.85;
    let direct = sun_color() * (diff * vis * sky_gate * rain_dim * sun_strength);

    var sky_amb = atmosphere(vec3<f32>(0.0, 1.0, 0.0)) * 0.9;
    sky_amb = mix(sky_amb, vec3<f32>(luminance(sky_amb)), frame.rain * 0.6);
    let ground = vec3<f32>(0.30, 0.26, 0.20) * (daylight() * 0.18 + 0.01);
    let up = n.y * 0.5 + 0.5;
    let floor_light = vec3<f32>(0.012 + frame.brightness * 0.02 + frame.night_vision * 0.2);
    let ambient = (mix(ground, sky_amb, up) * pow(light.y, 1.5) + floor_light) * ambient_strength * vec3<f32>(0.9, 1.0, 1.15);
    let torch = vec3<f32>(1.0, 0.58, 0.27) * (pow(light.x, 2.4) * 2.0 * block_light);
    return Lit(direct, ambient + torch, vis);
}

// Gradient of a sum of four travelling sine waves at world xz.
fn wave_gradient(p: vec2<f32>, t: f32) -> vec2<f32> {
    var g = vec2<f32>(0.0);
    g += vec2<f32>(0.92, 0.39) * (cos(dot(vec2<f32>(0.92, 0.39), p) * 1.7 + t * 1.2) * 0.30 * 1.7);
    g += vec2<f32>(-0.50, 0.87) * (cos(dot(vec2<f32>(-0.50, 0.87), p) * 2.9 + t * 1.7) * 0.18 * 2.9);
    g += vec2<f32>(0.28, -0.96) * (cos(dot(vec2<f32>(0.28, -0.96), p) * 4.7 + t * 2.3) * 0.10 * 4.7);
    g += vec2<f32>(-0.97, -0.24) * (cos(dot(vec2<f32>(-0.97, -0.24), p) * 7.9 + t * 3.1) * 0.05 * 7.9);
    return g;
}

// What lies behind a translucent surface: rgb linear colour, w distance behind it in blocks.
fn behind_sample(uv: vec2<f32>, surface_dist: f32) -> vec4<f32> {
    let dims = vec2<f32>(textureDimensions(opaque_depth));
    let p = vec2<i32>(clamp(uv * dims, vec2<f32>(0.0), dims - vec2<f32>(1.0)));
    let d = textureLoad(opaque_depth, p, 0);
    let col = textureLoad(opaque_color, p, 0).rgb;
    var dist = 64.0;
    if d > 0.0 {
        let q = frame.projection_inverse * vec4<f32>(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, d, 1.0);
        dist = length(q.xyz / q.w);
    }
    return vec4<f32>(to_linear(col), clamp(dist - surface_dist, -1.0, 64.0));
}

fn water_surface(input: MaterialInput) -> Surface {
    let l = light_dir();
    let v = normalize(-input.position);
    var n = normalize(input.normal);
    let dist = length(input.position);
    if n.y > 0.5 {
        let world_xz = (frame.camera_position + input.position).xz;
        let g = wave_gradient(world_xz, frame.time);
        let amp = 0.25 * water_waves * (1.0 + frame.rain) / (1.0 + dist * 0.015);
        n = normalize(n + vec3<f32>(-g.x, 0.0, -g.y) * amp);
    }
    let lit = lighting(vec3<f32>(0.0, 1.0, 0.0), input.position, vec2<f32>(input.light.x, max(input.light.y, 0.0)));
    let nlit = lighting(n, input.position, input.light);

    // Refraction and absorption.
    let warp = n.xz * 0.012 * water_waves;
    var b = behind_sample(input.screen + warp, dist);
    if b.w < 0.0 {
        b = behind_sample(input.screen, dist);
    }
    let thickness = max(b.w, 0.0);
    let k = mix(1.6, 0.35, water_clarity);
    let absorb = exp(-vec3<f32>(0.30, 0.075, 0.05) * (thickness * k));
    let water_col = to_linear(input.albedo.rgb * input.tint.rgb);
    let body = water_col * (nlit.direct * 0.35 + lit.indirect) * 0.6;
    var refracted = b.rgb * absorb + body * (vec3<f32>(1.0) - absorb);
    let foam = (1.0 - smoothstep(0.0, 0.35, thickness)) * 0.35;
    refracted += (nlit.direct + lit.indirect) * (foam * 0.5);

    // Reflection.
    let r = reflect(-v, n);
    var refl = atmosphere(vec3<f32>(r.x, abs(r.y), r.z));
    if water_reflections && frame.has_reflection == 1u {
        let ruv = clamp(input.screen + n.xz * 0.02 * water_waves, vec2<f32>(0.0), vec2<f32>(1.0));
        refl = to_linear(textureSampleLevel(reflection, reflection_sampler, ruv, 0.0).rgb);
    }
    let cosv = saturate1(dot(n, v));
    let fres = 0.02 + 0.98 * pow(1.0 - cosv, 5.0);
    var col = mix(refracted, refl, fres);
    col += nlit.direct * (pow(saturate1(dot(r, l)), 700.0) * 30.0);
    return Surface(vec4<f32>(to_display(tonemap(col)), 1.0));
}

fn material(input: MaterialInput) -> Surface {
    let vanilla = input.albedo * input.tint * vec4<f32>(input.lightmap, 1.0);
    if frame.dimension != 0 {
        // Nether and End keep vanilla's light; just let emissive blocks shine.
        return Surface(vec4<f32>(vanilla.rgb + input.albedo.rgb * (input.emission * 0.5), vanilla.a));
    }
    if input.fluid == 1u && input.translucent && frame.in_water < 0.5 {
        return water_surface(input);
    }

    let n = normalize(input.normal);
    let l = light_dir();
    let v = normalize(-input.position);
    let a_lin = to_linear(input.albedo.rgb);
    let maxc = max(input.tint.r, max(input.tint.g, input.tint.b));
    let hue = input.tint.rgb / max(maxc, 0.001);
    let ao_shade = mix(1.0, maxc, 0.5);
    let wet = frame.wetness * smoothstep(0.6, 0.95, input.light.y);

    var alb = a_lin * to_linear(hue);
    alb = mix(vec3<f32>(luminance(alb)), alb, 1.2);
    alb = alb * mix(1.0, 0.65, wet);
    let lit = lighting(n, input.position, input.light);
    var col = alb * (lit.direct + lit.indirect) * ao_shade + a_lin * (input.emission * 2.5);

    // Wet-surface sheen: a tight sun highlight on rain-soaked up-facing blocks.
    let h = normalize(l + v);
    col += lit.direct * (pow(saturate1(dot(n, h)), 160.0) * wet * 2.0 * saturate1(n.y));

    if input.fluid == 2u {
        col = a_lin * 3.0;
    }
    return Surface(vec4<f32>(to_display(tonemap(col)), input.albedo.a * input.tint.a));
}
