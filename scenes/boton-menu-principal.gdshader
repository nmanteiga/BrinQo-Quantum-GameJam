shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float chaos : hint_range(0.0, 30.0) = 0.0;
uniform float border_thickness : hint_range(0.0, 10.0) = 3.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	
	vec2 offset = vec2(0.0);
	if (chaos > 0.1) {
		float block_size = 20.0; 
		vec2 blocks = floor(uv * block_size);
		float noise_x = sin(dot(blocks, vec2(12.9898, 78.233)) + TIME * 10.0);
		float noise_y = cos(dot(blocks, vec2(39.346, 11.135)) - TIME * 10.0);
		offset = vec2(noise_x, noise_y) * chaos * 0.001;
	}
	
	vec3 background = texture(screen_texture, SCREEN_UV + offset).rgb;
	
	vec2 pixel_size = fwidth(UV); 
	vec2 border_size = pixel_size * border_thickness;
	
	vec2 top_left = step(uv, border_size);
	vec2 bottom_right = step(vec2(1.0) - border_size, uv);
	
	float border_mask = max(max(top_left.x, top_left.y), max(bottom_right.x, bottom_right.y));
	
	vec3 final_color = mix(background, border_color.rgb, border_mask * border_color.a);
	
	COLOR = vec4(final_color, 1.0);
}