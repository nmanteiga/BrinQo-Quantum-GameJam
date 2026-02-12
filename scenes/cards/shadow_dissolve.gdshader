// Simple dissolve shader for shadow (no 3D rotation)
shader_type canvas_item;

// Dissolve effect uniforms
uniform sampler2D dissolve_texture : source_color;
uniform float dissolve_value : hint_range(0, 1) = 0.0;
uniform float burn_size : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 burn_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);

void fragment(){
	vec4 main_texture = texture(TEXTURE, UV);
	// Apply the modulate color from the CanvasItem
	COLOR = main_texture * COLOR;
	
	// Apply dissolve effect only if dissolve_value > 0
	if (dissolve_value > 0.001) {
		vec4 noise_texture = texture(dissolve_texture, UV);
		
		// Invert dissolve so 1.0 = fully dissolved, 0.0 = fully visible
		float inv_dissolve = 1.0 - dissolve_value;
		
		// Avoid small burn_color dot when dissolve is 0 or 1
		float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
		float threshold = smoothstep(noise_texture.x - burn_size_step, noise_texture.x, inv_dissolve);
		float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, inv_dissolve);
		
		COLOR.a *= threshold;
		COLOR.rgb = mix(burn_color.rgb, COLOR.rgb, border);
	}
}
