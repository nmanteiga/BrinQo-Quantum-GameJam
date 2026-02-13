// Hey this is Hei! This shader "fakes" a 3D-camera perspective on CanvasItems.
// License: MIT
// Combined with dissolve effect

shader_type canvas_item;

// Camera FOV
uniform float fov : hint_range(1, 179) = 90;
uniform bool cull_back = true;
uniform float y_rot : hint_range(-180, 180) = 0.0;
uniform float x_rot : hint_range(-180, 180) = 0.0;
// At 0, the image retains its size when unrotated.
// At 1, the image is resized so that it can do a full
// rotation without clipping inside its rect.
uniform float inset : hint_range(0, 1) = 0.0;

// Dissolve effect uniforms
uniform sampler2D dissolve_texture : source_color;
uniform float dissolve_value : hint_range(0, 1) = 0.0;
uniform float burn_size : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 burn_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);

// Outline effect uniforms
uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width : hint_range(0, 10) = 2.0;
uniform int outline_pattern : hint_range(0, 2) = 1; // 0=diamond, 1=circle, 2=square
uniform bool outline_inside = true;
uniform bool outline_add_margins = false;

varying flat vec2 o;
varying vec3 p;


// Outline helper function
bool hasContraryNeighbour(vec2 uv, vec2 texture_pixel_size, sampler2D texture) {
	for (float i = -ceil(outline_width); i <= ceil(outline_width); i++) {
		float x = abs(i) > outline_width ? outline_width * sign(i) : i;
		float offset;
		
		if (outline_pattern == 0) {
			offset = outline_width - abs(x);
		} else if (outline_pattern == 1) {
			offset = floor(sqrt(pow(outline_width + 0.5, 2) - x * x));
		} else if (outline_pattern == 2) {
			offset = outline_width;
		}
		
		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			float y = abs(j) > offset ? offset * sign(j) : j;
			vec2 xy = uv + texture_pixel_size * vec2(x, y);
			
			if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || texture(texture, xy).a <= 0.0) == outline_inside) {
				return true;
			}
		}
	}
	
	return false;
}


// Creates rotation matrix
void vertex(){
	float sin_b = sin(y_rot / 180.0 * PI);
	float cos_b = cos(y_rot / 180.0 * PI);
	float sin_c = sin(x_rot / 180.0 * PI);
	float cos_c = cos(x_rot / 180.0 * PI);
	
	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;
	
	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;
	
	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;
	
	
	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * t * (1.0 - inset);
	
	// Apply outline margins if enabled
	if (outline_enabled && outline_add_margins) {
		VERTEX += (UV * 2.0 - 1.0) * outline_width;
	}
}

void fragment(){
	if (cull_back && p.z <= 0.0) discard;
	vec2 uv = (p.xy / p.z).xy - o;
	
	// Apply outline margins adjustment if enabled
	vec2 adjusted_uv = uv;
	vec2 texture_pixel_size = TEXTURE_PIXEL_SIZE;
	
	if (outline_enabled && outline_add_margins) {
		texture_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(outline_width * 2.0));
		adjusted_uv = (uv - texture_pixel_size * outline_width) * TEXTURE_PIXEL_SIZE / texture_pixel_size;
		
		if (adjusted_uv != clamp(adjusted_uv, vec2(-0.5), vec2(0.5))) {
			COLOR.a = 0.0;
		} else {
			vec4 main_texture = texture(TEXTURE, adjusted_uv + 0.5);
			COLOR = main_texture;
			COLOR.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
			
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
				COLOR.rgb = mix(burn_color.rgb, main_texture.rgb, border);
			}
			
			// Apply outline effect if enabled
			if (outline_enabled && (COLOR.a > 0.0) == outline_inside && hasContraryNeighbour(adjusted_uv + 0.5, texture_pixel_size, TEXTURE)) {
				COLOR.rgb = outline_inside ? mix(COLOR.rgb, outline_color.rgb, outline_color.a) : outline_color.rgb;
				COLOR.a += (1.0 - COLOR.a) * outline_color.a;
			}
		}
	} else {
		vec4 main_texture = texture(TEXTURE, adjusted_uv + 0.5);
		COLOR = main_texture;
		COLOR.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
		
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
			COLOR.rgb = mix(burn_color.rgb, main_texture.rgb, border);
		}
		
		// Apply outline effect if enabled
		if (outline_enabled && (COLOR.a > 0.0) == outline_inside && hasContraryNeighbour(adjusted_uv + 0.5, texture_pixel_size, TEXTURE)) {
			COLOR.rgb = outline_inside ? mix(COLOR.rgb, outline_color.rgb, outline_color.a) : outline_color.rgb;
			COLOR.a += (1.0 - COLOR.a) * outline_color.a;
		}
	}
}