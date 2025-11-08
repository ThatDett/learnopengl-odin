#version 330 core
out vec4 FragColor;

struct Material
{
    sampler2D diffuse;
    sampler2D specular;
    float     shininess;
};

struct Light
{
    vec3 position;

    vec3  ambient;
    vec3  diffuse;
    vec3  specular;
};

uniform Material material;
uniform Light    light;

in vec2 o_tex_coords;

in vec3 o_light_pos;
in vec3 o_normal;
in vec3 o_frag_pos;

void main()
{
    //ambient
    // vec3 text_pixel = ;
    vec3 ambient    = light.ambient * vec3(texture(material.diffuse, o_tex_coords));

    //diffuse
    vec3  normal         = normalize(o_normal);
    vec3  light_dir      = normalize(o_light_pos - o_frag_pos);
    float diffuse_factor = max(dot(normal, light_dir), 0.0);
    vec3  diffuse        = light.diffuse * diffuse_factor * vec3(texture(material.diffuse, o_tex_coords));

    //specular
    vec3  camera_dir          = normalize(-o_frag_pos);
    vec3  reflected_light_dir = reflect(-light_dir, normal);
    float spec                = pow(max(dot(camera_dir, reflected_light_dir), 0.0), material.shininess);
    vec3  specular            = light.specular * spec * vec3(texture(material.specular, o_tex_coords));

    FragColor      = vec4(ambient + diffuse + specular, 1.0);
}
