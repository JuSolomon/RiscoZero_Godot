shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int colunas = 2;
uniform int linhas = 3;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade_perto = 4.0;   // abaixo desta distância some por completo
uniform float fade_longe = 15.0;  // acima desta distância fica 100% visível

varying flat float indice;

void vertex() {
	indice = floor(INSTANCE_CUSTOM.r * float(colunas * linhas));
	// billboard mantendo a escala de cada nuvem
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float col = mod(indice, float(colunas));
	float lin = floor(indice / float(colunas));
	vec2 uv = (UV + vec2(col, lin)) / vec2(float(colunas), float(linhas));
	vec4 c = texture(atlas, uv);
	float perto = smoothstep(fade_perto, fade_longe, length(VERTEX));
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a * tint.a * perto;
}
