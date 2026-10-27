shader_type spatial;
render_mode specular_disabled;

uniform vec4 cor_fundo : source_color = vec4(0.17, 0.35, 0.55, 1.0);
uniform vec4 cor_onda : source_color = vec4(0.32, 0.55, 0.72, 1.0);
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform float escala = 0.05;          // tamanho das manchas (menor = maiores)
uniform vec2 vel_1 = vec2(0.010, 0.006);
uniform vec2 vel_2 = vec2(-0.007, 0.009);
uniform float intensidade : hint_range(0.0, 1.0) = 0.6;

varying vec3 pos_mundo;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = pos_mundo.xz * escala;
	float a = texture(ruido, uv + TIME * vel_1).r;
	float b = texture(ruido, uv * 1.7 + TIME * vel_2).r;
	float manchas = smoothstep(0.45, 0.75, (a + b) * 0.5);
	ALBEDO = mix(cor_fundo.rgb, cor_onda.rgb, manchas * intensidade);
	ROUGHNESS = 1.0;
}