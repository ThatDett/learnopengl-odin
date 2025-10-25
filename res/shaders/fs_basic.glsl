#version 330 core
out vec4 FragColor;

uniform vec3 object_color;
uniform vec3 light_color;

void main()
{
    FragColor = vec4(object_color * light_color, 1.0);
}
