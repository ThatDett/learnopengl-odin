#version 330 core
out vec4 FragColor;

struct Material
{
    sampler2D diffuse;
    sampler2D specular;
    float     shininess;
};

struct Phong
{
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct Directional_Light
{
    vec3  direction;
    Phong phong;
};

struct Fade
{
    float constant;
    float linear;
    float quadratic;
};

struct Point_Light
{
    vec3  position;

    Phong phong;
    Fade  fade;
};

struct Spot_Light
{
    vec3  position;
    vec3  direction;

    Phong phong;
    Fade  fade;

    float cutoff;
    float outer_cutoff;
};

#define NUMBER_OF_POINT_LIGHTS 4

uniform Material          material;
uniform Directional_Light directional_light;
uniform Point_Light       point_lights[NUMBER_OF_POINT_LIGHTS];
uniform Spot_Light        spot_light;

uniform vec3              view_pos;

in vec2 o_tex_coords;
in vec3 o_normal;
in vec3 o_frag_pos;

vec3 calculate_directional_light(Directional_Light dir_light, vec3 normal, vec3 view_dir)
{
    vec3 light_dir = normalize(-dir_light.direction);

    // diffuse shading
    float diffuse_factor = max(dot(normal, light_dir), 0.0);

    // specular shading
    vec3 reflect_dir      = reflect(-light_dir, normal);
    float specular_factor = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);

    vec3 ambient  = dir_light.phong.ambient  * vec3(texture(material.diffuse, o_tex_coords));
    vec3 diffuse  = dir_light.phong.diffuse  * diffuse_factor  * vec3(texture(material.diffuse, o_tex_coords));
    vec3 specular = dir_light.phong.specular * specular_factor * vec3(texture(material.specular, o_tex_coords));

    return ambient + diffuse + specular;
}

vec3 calculate_point_light(Point_Light point_light, vec3 normal, vec3 view_dir, vec3 frag_pos)
{
    vec3 light_dir = normalize(point_light.position - frag_pos);

    // diffuse shading
    float diffuse_factor = max(dot(normal, light_dir), 0.0);

    // specular shading
    vec3 reflect_dir      = reflect(-light_dir, normal);
    float specular_factor = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);

    // attenuation
    float distance    = length(point_light.position - frag_pos);
    float attenuation = 1.0 / (point_light.fade.constant + point_light.fade.linear * distance + point_light.fade.quadratic * distance * distance);    

    vec3 ambient  = point_light.phong.ambient  * vec3(texture(material.diffuse, o_tex_coords));
    vec3 diffuse  = point_light.phong.diffuse  * diffuse_factor  * vec3(texture(material.diffuse, o_tex_coords));
    vec3 specular = point_light.phong.specular * specular_factor * vec3(texture(material.specular, o_tex_coords));

    return attenuation * (ambient + diffuse + specular);
}

vec3 calculate_spot_light(Spot_Light spot_light, vec3 normal, vec3 view_dir, vec3 frag_pos)
{
    //ambient
    vec3  light_dir = normalize(spot_light.position - frag_pos);
    float theta     = dot(light_dir, normalize(-spot_light.direction));
    float epsilon   = spot_light.cutoff - spot_light.outer_cutoff;
    float intensity = clamp((theta - spot_light.outer_cutoff) / epsilon, 0.0, 1.0);

    vec3 ambient = spot_light.phong.ambient * vec3(texture(material.diffuse, o_tex_coords));

    //diffuse
    normal               = normalize(normal);
    float diffuse_factor = max(dot(normal, light_dir), 0.0);
    vec3  diffuse        = spot_light.phong.diffuse * diffuse_factor * vec3(texture(material.diffuse, o_tex_coords));

    //specular
    vec3  camera_dir          = normalize(view_pos - frag_pos);
    vec3  reflected_light_dir = reflect(-light_dir, normal);
    float specular_factor     = pow(max(dot(camera_dir, reflected_light_dir), 0.0), material.shininess);
    vec3  specular            = spot_light.phong.specular * specular_factor * vec3(texture(material.specular, o_tex_coords));

    // attenuation
    float distance    = length(spot_light.position - frag_pos);
    float attenuation = 1.0 / (spot_light.fade.constant + spot_light.fade.linear * distance + spot_light.fade.quadratic * distance * distance);    
    return (ambient + (diffuse + specular) * attenuation) * intensity;
}

void main()
{
    vec3 normal   = normalize(o_normal);
    vec3 view_dir = normalize(view_pos - o_frag_pos);

    vec3 result = vec3(0.0);
         result = calculate_directional_light(directional_light, normal, view_dir);
    for (int i = 0; i < NUMBER_OF_POINT_LIGHTS; i += 1)
    {
        result += calculate_point_light(point_lights[i], normal, view_dir, o_frag_pos);
    }

    result    += calculate_spot_light(spot_light, normal, view_dir, o_frag_pos); 
    FragColor  = vec4(result, 1.0);
}
