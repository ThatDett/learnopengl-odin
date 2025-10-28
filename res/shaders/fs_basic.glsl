#version 330 core
out vec4 FragColor;

uniform vec3 object_color;
uniform vec3 light_color;

in vec3 o_light_pos;
in vec3 o_normal;
in vec3 o_frag_pos;

void main()
{
    float ambient_factor = 0.1f;
    vec3  ambient        = light_color * ambient_factor;

    vec3  normal         = normalize(o_normal);
    vec3  light_dir      = normalize(o_light_pos - o_frag_pos);
    float diffuse_factor = max(dot(normal, light_dir), 0.1);
    vec3  diffuse        = light_color * diffuse_factor;

    vec3  camera_dir          = normalize(- o_frag_pos);
    float specular_factor     = 0.9;
    vec3  reflected_light_dir = reflect(-light_dir, normal);
    float spec                = pow(max(dot(camera_dir, reflected_light_dir), 0.0), 32);
    vec3  specular            = spec * light_color * specular_factor;

    FragColor      = vec4(object_color * (ambient + diffuse + specular), 1.0);
}
