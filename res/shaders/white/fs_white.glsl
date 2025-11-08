#version 330 core
out vec4 final_color;

uniform vec3 light_color;

void main()
{
    final_color = vec4(light_color, 1.0);
}
