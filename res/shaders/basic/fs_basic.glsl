#version 330 core
out vec4 FragColor;

struct Material
{
    vec3  ambient;
    vec3  diffuse;
    vec3  specular;
    float shininess;
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

// uniform vec3 object_color;
// uniform vec3 light_color;

in vec3 o_light_pos;
in vec3 o_normal;
in vec3 o_frag_pos;

void main()
{
    //ambient
    vec3  ambient        = light.ambient * material.ambient;

    //diffuse
    vec3  normal         = normalize(o_normal);
    vec3  light_dir      = normalize(o_light_pos - o_frag_pos);
    float diffuse_factor = max(dot(normal, light_dir), 0.0);
    vec3  diffuse        = light.diffuse * (diffuse_factor * material.diffuse);

    //specular
    vec3  camera_dir          = normalize(-o_frag_pos);
    vec3  reflected_light_dir = reflect(-light_dir, normal);
    float spec                = pow(max(dot(camera_dir, reflected_light_dir), 0.0), material.shininess);
    vec3  specular            = light.specular * (spec * material.specular);

    FragColor      = vec4(ambient + diffuse + specular, 1.0);
}
