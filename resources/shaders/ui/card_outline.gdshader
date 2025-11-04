shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(1.0, 10.0) = 2.0;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
    vec2 size = vec2(thickness) / vec2(textureSize(TEXTURE, 0));
    float is_edge = 0.0;

    // 检查边缘
    if (UV.x < size.x || UV.x > 1.0 - size.x || UV.y < size.y || UV.y > 1.0 - size.y) {
        is_edge = 1.0;
    }

    vec4 tex_color = texture(TEXTURE, UV);

    // 只有在边缘区域才进行混合计算
    if (is_edge > 0.5) {
        // 1. 准备描边颜色，并用 outline_strength 控制其透明度
        vec4 final_outline = outline_color;
        final_outline.a *= outline_strength; // 关键：描边的透明度由 strength 控制

        // 2. 进行 Alpha 混合
        // 使用标准的 "over" 操作混合公式: C = As*Ac + Bs*(1-Ac)
        // 其中 C 是最终颜色, A 是上层 (描边), B 是下层 (原图)
        // s 代表颜色分量, c 代表 alpha 分量
        COLOR.rgb = final_outline.rgb * final_outline.a + tex_color.rgb * (1.0 - final_outline.a);
        COLOR.a = final_outline.a + tex_color.a * (1.0 - final_outline.a);
    } else {
        // 如果不是边缘，直接使用原始纹理颜色
        COLOR = tex_color;
    }
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
