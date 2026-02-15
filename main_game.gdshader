shader_type canvas_item;

uniform vec4 grid_color : source_color = vec4(1.0, 1.0, 1.0, 0.08);
uniform vec4 bg_color : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform float cell_size = 40.0;
uniform float line_width = 1.0;
uniform float warp_strength = 0.015;
uniform vec2 warp_center = vec2(0.5, 0.65);

void fragment() {
    vec2 uv = UV;
    vec2 diff = uv - warp_center;
    float d = length(diff);
    float influence = smoothstep(0.45, 0.0, d);
    uv -= normalize(diff + vec2(0.0001)) * influence * warp_strength;

    vec2 grid = abs(fract(uv * (1.0 / max(cell_size / 1024.0, 0.0001))) - 0.5);
    float gx = smoothstep(0.5, 0.5 - line_width * 0.01, grid.x);
    float gy = smoothstep(0.5, 0.5 - line_width * 0.01, grid.y);
    float lines = max(gx, gy);

    COLOR = mix(bg_color, grid_color, lines);
}
