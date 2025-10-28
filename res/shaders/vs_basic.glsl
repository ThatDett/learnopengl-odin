#version 330 core
layout (location = 0) in vec3 a_pos;
layout (location = 1) in vec3 a_normal;

out vec3 o_normal;
out vec3 o_frag_pos;
out vec3 o_light_pos;

uniform vec3 light_pos;
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
    gl_Position = projection * view * model * vec4(a_pos, 1.0);
    o_normal    = mat3(transpose(inverse(view * model))) * a_normal;
    o_frag_pos  = vec3(view * model * vec4(a_pos, 1.0));
    o_light_pos = vec3(view * vec4(light_pos, 1.0));
}
