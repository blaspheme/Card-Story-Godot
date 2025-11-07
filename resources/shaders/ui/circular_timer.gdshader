shader_type canvas_item;

// 圆环进度条（可配置起始位置和旋转方向）
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float thickness : hint_range(0.01, 0.5) = 0.12;
uniform float radius : hint_range(0.0, 0.5) = 0.42;
uniform float edge_smooth : hint_range(0.0005, 0.02) = 0.004;

// 起始角度（0.0=右侧, 0.25=底部, 0.5=左侧, 0.75=顶部）
uniform float start_angle : hint_range(0.0, 1.0) = 0.25;
// 旋转方向（1.0=顺时针, -1.0=逆时针）
uniform float direction : hint_range(-1.0, 1.0) = -1.0;

const float PI2 = 6.283185307179586; // 2*PI

void fragment() {
    vec2 uv_c = UV - vec2(0.5);
    float dist = length(uv_c);

    // 获取当前像素相对于中心的角度
    float ang = atan(uv_c.y, uv_c.x);
    
    // 标准化到 [0, 2PI) 范围
    float normalized_angle = mod(ang + PI2, PI2);
    
    // 应用起始角度偏移和旋转方向
    float offset = start_angle * PI2;
    float adjusted_angle;
    
    if (direction > 0.0) {
        // 顺时针：从起始角度减去当前角度
        adjusted_angle = mod(offset - normalized_angle, PI2);
    } else {
        // 逆时针：当前角度减去起始角度
        adjusted_angle = mod(normalized_angle - offset, PI2);
    }
    
    // 当前进度对应的角度
    float sweep = clamp(progress, 0.0, 1.0) * PI2;
    
    // 判断当前像素是否在进度范围内
    float angle_mask = step(adjusted_angle, sweep);

    // 圆环半径遮罩
    float inner_r = radius - thickness * 0.5;
    float outer_r = radius + thickness * 0.5;

    float a = smoothstep(inner_r - edge_smooth, inner_r + edge_smooth, dist);
    float b = smoothstep(outer_r + edge_smooth, outer_r - edge_smooth, dist);
    float ring_mask = clamp(a * b, 0.0, 1.0);

    // 合并遮罩并混合颜色
    float mask = angle_mask * ring_mask;
    COLOR = mix(bg_color, color, mask);
}
