#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float value;    // HSV brightness 0..1
};

const float TAU = 6.28318530718;

vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float r = length(p);
    float h = fract(atan(p.y, p.x) / TAU);
    float aa = max(fwidth(r), 0.002);
    float a = 1.0 - smoothstep(1.0 - aa, 1.0, r);
    vec3 rgb = hsv2rgb(vec3(h, clamp(r, 0.0, 1.0), value));
    fragColor = vec4(rgb * a, a) * qt_Opacity;
}
