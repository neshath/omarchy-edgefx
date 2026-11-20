#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float speed;
    vec2 size;      // item size in px
    vec4 box;       // x, y, w, h of the lit rectangle inside the item
    vec4 params;    // radius, outward (+1 windows / -1 screen), glow width, led width
    int mode;
    float dir;      // +1 clockwise, -1 counter-clockwise
    float uAudioEnabled;
    float uAudioSensitivity;
    float uAudioIdleDim;
    vec4 uAudio;    // x=level y=bass z=mid w=treble (0..1)
    vec4 occ0;      // occluding window rects (w <= 0 means unused)
    vec4 occ1;
    vec4 occ2;
    vec4 occ3;
    vec4 pal0;
    vec4 pal1;
    vec4 pal2;
    vec4 pal3;
    vec4 pal4;
    vec4 pal5;
};

const float TAU = 6.28318530718;
const float PI = 3.14159265359;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

// 18 Matrix-style glyphs, 5x5 bitmasks (25 bits, bit = row*5 + col, row 0 on top).
const uint GLY[18] = uint[18](
    0x1f27c9fu,
    0x04213e4u,
    0x032321fu,
    0x022222eu,
    0x118c7f1u,
    0x04f910fu,
    0x04217c2u,
    0x1f0bc3fu,
    0x04255c4u,
    0x115111fu,
    0x1577dd5u,
    0x115113eu,
    0x01113c3u,
    0x1f8d63fu,
    0x0a27c84u,
    0x0727087u,
    0x11511e1u,
    0x1a2908eu
);


vec3 palAt(int i) {
    if (i == 0) return pal0.rgb;
    if (i == 1) return pal1.rgb;
    if (i == 2) return pal2.rgb;
    if (i == 3) return pal3.rgb;
    if (i == 4) return pal4.rgb;
    return pal5.rgb;
}

vec3 pal(float x) {
    x = fract(x) * 6.0;
    int i = int(floor(x));
    float f = x - float(i);
    f = f * f * (3.0 - 2.0 * f);
    return mix(palAt(i % 6), palAt((i + 1) % 6), f);
}

float sdRound(vec2 p, vec4 r, float rad) {
    vec2 hs = r.zw * 0.5;
    vec2 q = abs(p - (r.xy + hs)) - hs + rad;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
}

// Clockwise arc-length position (px) of the point's nearest edge location.
float perimeterPos(vec2 p, vec4 r) {
    vec2 hs = r.zw * 0.5;
    vec2 q = p - (r.xy + hs);
    float W = r.z, H = r.w;
    if (abs(q.x) - hs.x > abs(q.y) - hs.y) {
        float y = clamp(q.y + hs.y, 0.0, H);
        return q.x > 0.0 ? W + y : 2.0 * W + H + (H - y);
    }
    float x = clamp(q.x + hs.x, 0.0, W);
    return q.y < 0.0 ? x : W + H + (W - x);
}

// Capsule LED cell along the path: returns signed distance to the capsule.
float capsule(float s, float pitch, float halfLen, float across, float ledR) {
    float a = mod(s, pitch) - pitch * 0.5;
    return length(vec2(max(abs(a) - halfLen, 0.0), across)) - ledR;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float rad = params.x;
    float outward = params.y;
    float gw = params.z;
    float led = params.w;

    // Music Sync (real audio only when enabled; modes 18-20 fall back to a demo beat).
    float aOn = step(0.5, uAudioEnabled);
    vec4 au = clamp(uAudio * uAudioSensitivity, 0.0, 1.5);
    float punch = aOn * au.y;
    led *= 1.0 + 0.5 * punch;
    gw *= 1.0 + 0.35 * punch;
    float audioGain = 1.0 + 0.9 * punch;
    float audioDim = 1.0;
    if (aOn > 0.0 && uAudioIdleDim > 0.5) audioDim = 0.18 + 0.82 * smoothstep(0.03, 0.2, uAudio.x * uAudioSensitivity);

    // Occlusion by windows stacked above this one.
    vec4 o[4] = vec4[4](occ0, occ1, occ2, occ3);
    for (int k = 0; k < 4; k++) {
        if (o[k].z > 0.0 && sdRound(p, o[k], rad) < 0.0) { fragColor = vec4(0.0); return; }
    }

    float d = sdRound(p, box, rad);
    // Windows: only light the outside of the rect. Screen: only the inside.
    if (outward > 0.0 && d < 0.0) { fragColor = vec4(0.0); return; }
    if (outward < 0.0 && d > 0.0) { fragColor = vec4(0.0); return; }

    float d0 = outward * (led * 0.5 + 1.0);
    float across = d - d0;
    float e = abs(across);

    float L = 2.0 * (box.z + box.w);
    float s = perimeterPos(p, box);
    if (dir < 0.0) s = L - s;
    float t = s / L;
    float tm = time * speed;
    if (aOn < 0.5) {                        // demo beat so audio modes still animate (and preview)
        au = vec4(0.5, pow(0.5 + 0.5 * sin(tm * 5.0), 6.0) * 0.9, 0.45 + 0.35 * sin(tm * 1.9 + 1.0), 0.35 + 0.3 * sin(tm * 3.3 + 2.0));
    }
    float coreMask = 1.0 - smoothstep(led * 0.5 - 0.6, led * 0.5 + 0.6, e);
    float glow = exp(-e / gw);
    float I = 0.0;
    vec3 col = pal(t + tm * 0.03);

    if (mode == 0) {                        // comet-trail
        float v = 320.0;
        float acc = 0.0;
        for (int k = 0; k < 2; k++) {
            float head = mod(tm * v + float(k) * L * 0.5, L);
            float behind = mod(head - s, L);
            float trail = exp(-behind / 120.0) * (1.0 - smoothstep(260.0, 340.0, behind));
            float dc = capsule(s, 26.0, 8.0, across, led * 0.5);
            float c = (1.0 - smoothstep(-0.6, 0.6, dc)) + 0.55 * exp(-max(dc, 0.0) / gw);
            acc = max(acc, c * trail);
            if (k == 0 && behind < 6.0) col = mix(col, vec3(1.0), 0.5);
        }
        I = acc;
        col = pal(t * 1.0 + tm * 0.05);
    } else if (mode == 1) {                 // pixel-trail
        float blk = 9.0;
        float sq = floor(s / blk) * blk;
        float head = floor(mod(tm * 260.0, L) / blk) * blk;
        float behind = mod(head - sq, L);
        float lvl = floor(4.0 * exp(-behind / 170.0) * (1.0 - smoothstep(300.0, 380.0, behind))) / 4.0;
        float rowOk = step(abs(across), blk * 0.5);
        float chk = mod(floor(s / blk) + floor(across / blk), 2.0);
        I = rowOk * lvl * (0.75 + 0.25 * chk);
        col = pal(t + tm * 0.04);
    } else if (mode == 2) {                 // light-bloom
        float pulse = 0.5 + 0.5 * sin(tm * 1.6 - t * TAU * 2.0);
        float w = gw * (2.0 + 3.5 * pulse);
        I = (exp(-e / w) * (0.35 + 0.65 * pulse)) * 0.9 + coreMask * 0.35 * pulse;
        col = pal(t * 0.5 + tm * 0.02);
    } else if (mode == 3) {                 // overflow-sweep
        float sweep = pow(0.5 + 0.5 * cos(TAU * (t - tm * 0.05)), 3.0);
        I = exp(-e / (gw * 6.0)) * (0.2 + 0.8 * sweep) + coreMask * 0.25 * sweep;
        col = pal(t - tm * 0.05);
    } else if (mode == 4) {                 // converge-flash
        float c = fract(tm * 0.15);
        float half_ = L * 0.5;
        float aPos = c * half_;
        float bPos = L - c * half_;
        float da = abs(s - aPos); da = min(da, L - da);
        float db = abs(s - bPos); db = min(db, L - db);
        float beam = max(exp(-da / 45.0), exp(-db / 45.0));
        float tailA = (s < aPos) ? exp(-(aPos - s) / 160.0) : 0.0;
        float tailB = (s > bPos) ? exp(-(s - bPos) / 160.0) : 0.0;
        float b = max(beam, max(tailA, tailB) * 0.6);
        float f = smoothstep(0.9, 0.96, c) * (1.0 - smoothstep(0.96, 1.0, c));
        I = (coreMask + 0.55 * glow) * b + (coreMask + 0.9 * glow) * f * 1.4;
        col = mix(pal(0.0 + tm * 0.03), pal(0.5 + tm * 0.03), step(L * 0.5, s));
        col = mix(col, vec3(1.0), f * 0.6);
    } else if (mode == 5) {                 // accelerating-streak
        float ph = fract(tm * 0.18);
        float pos = ph * ph * L * 2.0;
        float len = 30.0 + ph * 220.0;
        float behind = mod(pos - s, L * 0.25);
        float streak = (1.0 - smoothstep(0.0, len, behind)) * step(behind, len);
        I = (coreMask + 0.5 * glow) * streak;
        col = pal(t * 2.0 + tm * 0.06);
    } else if (mode == 6) {                 // segment-chase
        float n = max(8.0, floor(L / 60.0));
        float x = t * n;
        float idx = floor(x);
        float u = fract(x);
        float gap = smoothstep(0.08, 0.14, u) * (1.0 - smoothstep(0.86, 0.92, u));
        float cur = mod(idx - floor(tm * 7.0), n);
        float lit = cur < n * 0.25 ? 1.0 - cur / (n * 0.25) : 0.0;
        float lvl = 0.1 + 0.9 * lit;
        I = (coreMask + 0.5 * glow * lit) * gap * lvl;
        col = pal(idx / n);
    } else if (mode == 7) {                 // full-light-strip
        I = coreMask * 0.95 + glow * 0.6;
        col = pal(t + tm * 0.06);
    } else if (mode == 8) {                 // silk-line
        float ew = abs(across + sin(s * 0.03 - tm * 2.0) * 0.6);
        float thin = 1.0 - smoothstep(0.4, 1.5, ew);
        float sheen = pow(0.5 + 0.5 * cos(TAU * (t - tm * 0.07)), 6.0);
        float flow = 0.5 + 0.5 * sin(TAU * (t * 2.0 - tm * 0.12));
        I = thin * (0.6 + 0.4 * sheen) + exp(-e / (gw * 0.5)) * (0.15 + 0.25 * flow + 0.45 * sheen);
        col = pal(t + tm * 0.02);
    } else if (mode == 9) {                 // breathing-pulse
        float b = 0.5 - 0.5 * cos(tm * 1.2);
        b = b * b * (3.0 - 2.0 * b);
        float w = gw * (0.8 + 3.2 * b);
        I = exp(-e / w) * (0.25 + 0.75 * b) + coreMask * (0.25 + 0.4 * b);
        col = pal(t * 0.3 + tm * 0.03);
    } else if (mode == 10) {                // aurora-wave
        vec3 acc = vec3(0.0);
        float tot = 0.0;
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float wv = 0.5 + 0.5 * sin(t * TAU * (2.0 + fk) + tm * (0.5 + 0.3 * fk) + fk * 2.1);
            float rw = gw * (1.6 + 2.4 * wv);
            float c = exp(-e / rw) * wv * wv * 0.62;
            acc += pal(0.25 * fk + t * 0.5 + tm * 0.02) * c;
            tot += c;
        }
        I = tot + coreMask * 0.18;
        col = tot > 0.001 ? acc / tot : pal(t);
    } else if (mode == 11) {                // prism-refract
        float x = t - tm * 0.08;
        vec3 spec = 0.5 + 0.5 * cos(TAU * (x * 3.0 + vec3(0.0, 1.0 / 3.0, 2.0 / 3.0)));
        col = mix(pal(x), spec, 0.5);
        I = coreMask * 0.95 + glow * 0.55;
    } else if (mode == 12) {                // dual-orbit
        float a1 = fract(tm * 0.07);
        float d1 = abs(t - a1); d1 = min(d1, 1.0 - d1);
        float d2 = abs(t - fract(a1 + 0.5)); d2 = min(d2, 1.0 - d2);
        float arc1 = 1.0 - smoothstep(0.0, 0.14, d1);
        float arc2 = 1.0 - smoothstep(0.0, 0.14, d2);
        float arc = max(arc1, arc2);
        I = (coreMask + 0.7 * glow) * arc * arc + coreMask * 0.07;
        col = mix(pal(0.0 + tm * 0.02), pal(0.5 + tm * 0.02), step(arc1, arc2));
    } else if (mode == 13) {                // radar-sweep
        vec2 c = box.xy + box.zw * 0.5;
        float ang = fract(atan(p.y - c.y, p.x - c.x) / TAU);
        if (dir < 0.0) ang = 1.0 - ang;
        float delta = fract(fract(tm * 0.12) - ang);
        float trail = exp(-delta * 5.0);
        float beam = exp(-delta * 70.0);
        I = (coreMask * 0.8 + glow * 0.8) * (trail * 0.85 + beam) + coreMask * 0.05;
        col = mix(pal(delta * 0.5 + tm * 0.01), vec3(1.0), beam * 0.5);
    } else if (mode == 14) {                // plasma-flow
        float v = sin(s * 0.02 + tm * 1.7) + sin(s * 0.037 - tm * 1.3)
                + sin(s * 0.011 + across * 0.2 + tm * 0.9) + sin(length(vec2(s * 0.013, across * 0.3)) * 2.0 - tm);
        float pl = clamp(0.5 + v / 8.0, 0.0, 1.0);
        I = exp(-e / (gw * (1.0 + 1.5 * pl))) * (0.3 + 0.7 * pl) + coreMask * 0.5 * pl;
        col = pal(pl + t * 0.3 + tm * 0.02);
    } else if (mode == 15) {                // spark-ember
        float acc = 0.0;
        vec3 ecol = vec3(0.0);
        for (int k = 0; k < 2; k++) {
            float cell = k == 0 ? 40.0 : 57.0;
            float id = floor(s / cell) + float(k) * 91.0;
            float r1 = hash(id), r2 = hash(id + 7.3);
            float ph = fract(tm * 0.3 * (0.5 + r1) + r2);
            float br = sin(PI * ph);
            br *= br;
            float a = mod(s, cell) - cell * 0.5 - (r1 - 0.5) * cell * 0.5;
            float ac = across - outward * ph * 14.0;
            float dd = length(vec2(a, ac));
            float em = exp(-dd / 3.5) * br;
            acc += em;
            ecol += pal(r1 + tm * 0.02) * em;
        }
        I = acc * 1.6 + coreMask * 0.06 + glow * 0.05;
        col = acc > 0.001 ? ecol / acc : pal(t);
    } else if (mode == 16) {                // corner-glow
        vec4 b = box;
        vec2 c0 = b.xy, c1 = b.xy + vec2(b.z, 0.0), c2 = b.xy + b.zw, c3 = b.xy + vec2(0.0, b.w);
        float dd0 = length(p - c0), dd1 = length(p - c1), dd2 = length(p - c2), dd3 = length(p - c3);
        float dc = min(min(dd0, dd1), min(dd2, dd3));
        float idx = dc == dd0 ? 0.0 : (dc == dd1 ? 1.0 : (dc == dd2 ? 2.0 : 3.0));
        float reach = min(b.z, b.w) * 0.12 + 40.0;
        float corner = exp(-dc / reach) * (0.8 + 0.2 * sin(tm * 1.5 + idx * 1.57));
        I = (coreMask + 0.8 * glow) * corner + coreMask * 0.1;
        col = pal(idx / 4.0 + tm * 0.02);
    } else if (mode == 17) {                // neon-flicker
        float seg = floor(t * 8.0);
        float tick = floor(tm * 9.0);
        float drop = step(0.9, hash(seg + tick * 3.7));
        float flick = 1.0 - 0.65 * drop;
        flick *= 1.0 - 0.18 * step(0.93, hash(floor(tm * 18.0)));
        flick *= 0.94 + 0.06 * sin(tm * 47.0 + s * 0.01);
        I = (coreMask * 0.95 + glow * 0.7) * flick;
        col = pal(t * 0.6 + tm * 0.01);
    } else if (mode == 18) {                // audio-spectrum
        float x = 1.0 - abs(2.0 * t - 1.0);
        float bandsN = 24.0;
        float bi = floor(x * bandsN);
        float u = fract(x * bandsN);
        float gap = smoothstep(0.08, 0.18, u) * (1.0 - smoothstep(0.82, 0.92, u));
        float amp = au.y * (1.0 - smoothstep(0.0, 0.4, x))
                  + au.z * smoothstep(0.0, 0.4, x) * (1.0 - smoothstep(0.4, 0.8, x))
                  + au.w * smoothstep(0.5, 1.0, x);
        amp *= 0.85 + 0.15 * sin(bi * 1.7 + tm * 3.0);
        amp = clamp(amp + 0.12 * au.x, 0.0, 1.4);
        float barH = 6.0 + amp * 56.0;
        float bar = (1.0 - smoothstep(barH * 0.7, barH, e)) * (0.35 + 0.65 * (1.0 - clamp(e / barH, 0.0, 1.0)));
        I = bar * gap * (0.4 + 0.6 * amp) + coreMask * 0.2;
        col = pal(x + tm * 0.02);
    } else if (mode == 19) {                // bass-pulse
        vec2 c = box.xy + box.zw * 0.5;
        float r = length(p - c) / max(length(box.zw * 0.5), 1.0);
        float front = exp(-fract(r * 2.0 - tm * 0.5) * 6.0);
        float kick = au.y;
        I = (coreMask + 0.8 * glow) * (0.12 + kick * front * 1.8) + exp(-e / (gw * 3.0)) * kick * 0.5;
        col = pal(r * 0.8 + tm * 0.03);
    } else if (mode == 20) {                // eq-wave
        float amp = 0.3 + au.x * 1.2;
        float w = sin(s * 0.02 + tm * 3.0) * 7.0 * (0.4 + au.y)
                + sin(s * 0.047 - tm * 2.0) * 4.0 * (0.4 + au.z)
                + sin(s * 0.09 + tm * 5.0) * 3.0 * (0.4 + au.w);
        float rd = abs(across - outward * (6.0 + w * amp));
        float ribbon = 1.0 - smoothstep(led * 0.5, led * 0.5 + 1.2, rd);
        I = ribbon + exp(-rd / gw) * 0.5 + coreMask * 0.15;
        col = pal(t + tm * 0.04);
    } else {                                // matrix-rain (21)
        bool small = min(box.z, box.w) < 220.0;          // preview cards use a finer grid
        float cs = small ? 6.0 : 9.0;
        float bandW = small ? 26.0 : max(34.0, led * 12.0);
        bandW *= 1.0 + 0.5 * punch;
        if (outward > 0.0) bandW = min(bandW, 46.0);
        float dep = outward > 0.0 ? d : -d;
        vec2 q = p - box.xy;
        float cx = floor(q.x / cs);
        float cy = floor(q.y / cs);
        vec2 uv = vec2(fract(q.x / cs), fract(q.y / cs));
        float rr = dir < 0.0 ? -cy : cy;                 // reversed direction rises
        float mut = 1.0 + 1.5 * aOn * au.w;              // treble speeds up glyph mutation
        vec3 acc = vec3(0.0);
        float tot = 0.0;
        for (int k = 0; k < 2; k++) {
            float h = hash(cx * 1.37 + float(k) * 57.1 + 11.0);
            float h2 = hash(cx * 3.11 + float(k) * 13.7 + 5.0);
            float cyc = 36.0 + floor(h * 30.0);
            float trail = (8.0 + h * 12.0) * (1.0 + 0.5 * punch);
            float headRow = mod(tm * (6.0 + h2 * 10.0) + h2 * cyc * 7.0, cyc);
            float dh = mod(headRow - rr, cyc);
            if (dh < trail) {
                float lum = exp(-dh / (trail * 0.33)) * (1.0 - smoothstep(trail * 0.7, trail, dh));
                float headF = 1.0 - smoothstep(0.0, 1.0, dh);
                float period = 0.12 + 0.18 * hash(cx * 1.1 + cy * 5.1 + float(k));
                float tick = floor(time * mut / period + hash(cx * 0.7 + cy * 2.3) * 10.0);
                int gi = int(floor(hash(cx * 7.7 + cy * 3.3 + tick * 17.0 + float(k) * 5.0) * 18.0));
                vec2 g = (uv - 0.12) / 0.76;
                float px = 0.0;
                if (g.x >= 0.0 && g.x < 1.0 && g.y >= 0.0 && g.y < 1.0) {
                    ivec2 ip = ivec2(floor(g * 5.0));
                    vec2 fp = fract(g * 5.0);
                    float bit = float((GLY[gi] >> uint(ip.y * 5 + ip.x)) & 1u);
                    float dm = smoothstep(0.0, 0.22, fp.x) * (1.0 - smoothstep(0.78, 1.0, fp.x))
                             * smoothstep(0.0, 0.22, fp.y) * (1.0 - smoothstep(0.78, 1.0, fp.y));
                    px = bit * dm;
                }
                float bloom = (1.0 - smoothstep(0.0, 0.75, length(uv - 0.5))) * 0.22;
                float c = lum * (px * (1.0 + 0.6 * headF) + bloom);
                vec3 primary = pal(fract(h * 0.9));
                acc += mix(primary, vec3(0.88, 1.0, 0.92), headF) * c;
                tot += c;
            }
        }
        float bandMask = 1.0 - smoothstep(bandW * 0.45, bandW, dep);
        I = tot * bandMask * 1.15;
        col = tot > 0.001 ? acc / tot : pal(0.0);
    }

    float a = clamp(I * intensity * ((mode < 18 || mode == 21) ? audioGain : 1.0) * audioDim, 0.0, 1.0);
    vec3 rgb = mix(col, vec3(1.0), 0.28 * coreMask * a * (mode == 21 ? 0.0 : 1.0));
    if (outward > 0.0) a *= smoothstep(0.0, 1.0, d);
    fragColor = vec4(rgb * a, a) * qt_Opacity;
}
