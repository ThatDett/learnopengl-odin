package learn_opengl

import "core:os"
import "core:encoding/json"
import "core:fmt"

/////////////// - Enums - ///////////////
Imgui_Error :: enum
{
    nil,
    marshal,
    opening,
    writing,
}

/////////////// - Structs - ///////////////
Imgui_Data :: struct
{
    material_ambient:  Vector3,
    material_diffuse:  Vector3,
    material_specular: Vector3,
    shininess:         f32,

    light_color:    Vector3,
    light_ambient:  Vector3,
    light_diffuse:  Vector3,
    light_specular: Vector3,
}

/////////////// - Procedures - ///////////////
save_imgui_data :: proc(filename: string, data: Imgui_Data) -> Imgui_Error
{
    handle, err := os.open(filename, os.O_WRONLY | os.O_CREATE)
    if err != nil {
        return .opening
    }

    defer os.close(handle)

    json_data, json_err := json.marshal(data)
    if json_err != nil {
        fmt.println(json_err)
        return .marshal
    }

    if !os.write_entire_file(filename, json_data) {
        return .writing
    }

    return nil
}

load_imgui_data :: proc(filename: string, default_value := Imgui_Data{}) -> (loaded_value: Imgui_Data)
{
    data, ok := os.read_entire_file_from_filename(filename)
    defer delete(data)

    if ok {
        if json.unmarshal(data, &loaded_value) == nil {
            return loaded_value
        }

        return default_value
    }

    return default_value
}
