shader_type canvas_item;

uniform float star_density = 250.0;
uniform vec2 star_speed = vec2(0.02, 0.05);

float rand(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV + TIME * star_speed;

    vec2 gv = fract(uv * star_density);
    vec2 id = floor(uv * star_density);

    float r = rand(id);
    float star = step(0.995, r);

    float d = length(gv - 0.5);
    float size = mix(0.3, 1.0, r);
	star *= size;


    COLOR = vec4(vec3(star), 1.0);
}
