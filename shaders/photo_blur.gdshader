shader_type canvas_item;

// ============================================================
//  手机相册里的「偷拍照片」
//
//  一张照片看不清，通常不是因为分辨率低，而是因为：
//    · 对焦糊了（blur）
//    · 玻璃/镜头上有一大片过曝的晕光（glare）
//    · 有一道斜向的反光条
//    · 整体被冲淡、发灰（wash）
//    · 底片颗粒（grain）
//
//  玩家反复「擦掉反光」→ clarity 上升 → 上面五项一起减弱 → 才认得出那处原貌。
//  擦到极限还是糊的，就是一张废片（信息不全）。
// ============================================================

uniform float blur : hint_range(0.0, 14.0) = 8.0;
uniform float glare : hint_range(0.0, 1.0) = 0.85;
uniform float wash : hint_range(0.0, 1.0) = 0.45;
uniform float grain : hint_range(0.0, 1.0) = 0.35;
uniform vec2 glare_at = vec2(0.34, 0.30);
uniform float band_angle = 0.55;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * blur;
	vec4 acc = vec4(0.0);
	acc += texture(TEXTURE, UV + vec2(-1.0, -1.0) * texel);
	acc += texture(TEXTURE, UV + vec2( 0.0, -1.0) * texel);
	acc += texture(TEXTURE, UV + vec2( 1.0, -1.0) * texel);
	acc += texture(TEXTURE, UV + vec2(-1.0,  0.0) * texel);
	acc += texture(TEXTURE, UV + vec2( 0.0,  0.0) * texel);
	acc += texture(TEXTURE, UV + vec2( 1.0,  0.0) * texel);
	acc += texture(TEXTURE, UV + vec2(-1.0,  1.0) * texel);
	acc += texture(TEXTURE, UV + vec2( 0.0,  1.0) * texel);
	acc += texture(TEXTURE, UV + vec2( 1.0,  1.0) * texel);
	acc /= 9.0;

	vec3 c = acc.rgb;
	float a = acc.a;

	// ---- 大片过曝的晕光 ----
	float d = distance(UV, glare_at);
	float g = smoothstep(0.90, 0.02, d);
	g = pow(g, 1.7) * glare;
	c = mix(c, vec3(1.0, 0.99, 0.93), clamp(g, 0.0, 1.0));

	// ---- 斜向的反光条 ----
	float band = sin((UV.x * band_angle + UV.y * 0.42) * 8.5 + 1.3);
	float b = smoothstep(0.45, 1.0, band);
	c += vec3(0.34) * b * glare;

	// ---- 整体冲淡发灰 ----
	c = mix(c, vec3(0.83, 0.84, 0.79), wash);

	// ---- 底片颗粒 ----
	float n = rnd(UV * 640.0 + vec2(TIME * 7.0, TIME * 3.0));
	c += (n - 0.5) * grain;

	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), a);
}
