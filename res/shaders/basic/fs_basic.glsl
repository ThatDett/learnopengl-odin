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
    vec3 direction;

    vec3  ambient;
    vec3  diffuse;
    vec3  specular;
    
    float cutoff;
    float outer_cutoff;
    float constant;
    float linear;
    float quadratic;
};

uniform Material material;
uniform Light    light;
uniform vec3     view_pos;

in vec2 o_tex_coords;

// in vec3 o_light_pos;
// in vec3 o_light_dir;
in vec3 o_normal;
in vec3 o_frag_pos;

void main()
{
    //ambient
    vec3  light_dir = normalize(light.position - o_frag_pos);
    float theta     = dot(light_dir, normalize(-light.direction));
    float epsilon   = light.cutoff - light.outer_cutoff;
    float intensity = clamp((theta - light.outer_cutoff) / epsilon, 0.0, 1.0);

    // if (theta > light.cutoff)
    // {
        vec3 ambient = light.ambient * vec3(texture(material.diffuse, o_tex_coords));

        //diffuse
        vec3  normal         = normalize(o_normal);
        float diffuse_factor = max(dot(normal, light_dir), 0.0);
        vec3  diffuse        = light.diffuse * diffuse_factor * vec3(texture(material.diffuse, o_tex_coords));

        //specular
        vec3  camera_dir          = normalize(view_pos - o_frag_pos);
        vec3  reflected_light_dir = reflect(-light_dir, normal);
        float spec                = pow(max(dot(camera_dir, reflected_light_dir), 0.0), material.shininess);
        vec3  specular            = light.specular * spec * vec3(texture(material.specular, o_tex_coords));

        // attenuation
        float distance    = length(light.position - o_frag_pos);
        float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    

        // ambient  *= attenuation; // remove attenuation from ambient, as otherwise at large distances the light would be darker inside than outside the spotlight due the ambient term in the else branch
        FragColor = vec4(ambient + (diffuse + specular) * attenuation * intensity, 1.0);
    // }
    // else
    // {
    //     FragColor = vec4(light.ambient * vec3(texture(material.diffuse, o_tex_coords)), 1.0);
    //     // FragColor = vec4(0.0, 1.0, 0.0, 1.0);
    // }
}
