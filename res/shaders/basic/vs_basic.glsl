#version 330 core
layout (location = 0) in vec3 a_pos;
layout (location = 1) in vec3 a_normal;
layout (location = 2) in vec2 a_texture_coords;

out vec3 o_normal;
out vec3 o_frag_pos;
// out vec3 o_light_pos;
// out vec3 o_light_dir;

out vec2 o_tex_coords;

// uniform vec3 light_pos;
// uniform vec3 light_dir;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
    o_normal     = mat3(transpose(inverse(model))) * a_normal;
    o_frag_pos   = vec3(model * vec4(a_pos, 1.0));
    // o_light_pos  = vec3(view * vec4(light_pos, 1.0));
    // o_light_dir  = vec3(view * vec4(light_dir, 0.0));
    o_tex_coords = a_texture_coords;
    gl_Position  = projection * view * vec4(o_frag_pos, 1.0);
}
