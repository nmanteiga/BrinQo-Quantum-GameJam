shader_type canvas_item;

uniform vec2 resolution = vec2(1152.0, 648.0);
uniform sampler2D noise_texture: filter_nearest, repeat_enable;
uniform float density: hint_range(1.0, 100.0, 0.1) = 20.0;

uniform float rotation_speed: hint_range(-1.0, 1.0, 0.001) = 0.02; 
uniform float spiral_curve: hint_range(-10.0, 10.0, 0.01) = 3.0;

uniform vec2 center_offset = vec2(0.5, 1.0); 

uniform float layers: hint_range(1.0, 10.0, 1.0) = 5.0;

void fragment() {
	vec2 uv = UV;
	float aspect = resolution.x / resolution.y;
	uv.x *= aspect;
	
	vec2 center = vec2(center_offset.x * aspect, center_offset.y);
	vec2 rel_uv = uv - center;
	float dist = length(rel_uv);
	float angle = atan(rel_uv.y, rel_uv.x);
	
	float stars = 0.0;
	
	for (float i = 0.0; i < layers; i += 1.0) {
		float layer_shift = i * 0.2;
		float brightness = 1.0 - i * 0.2;
		
		float new_angle = angle + (TIME * rotation_speed) + (dist * spiral_curve) + (i * 0.5);
		
		vec2 spiral_uv = vec2(cos(new_angle), sin(new_angle)) * dist;
		
		vec2 movement = vec2(TIME * rotation_speed * 0.5); 
		
		stars += step(0.2, pow(texture(noise_texture, spiral_uv + movement + layer_shift).r, density)) * brightness;
	}
	
	COLOR = vec4(vec3(stars), 1.0);
}