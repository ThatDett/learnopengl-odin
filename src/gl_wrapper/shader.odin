package gl_wrapper

import      "core:os"
import      "core:fmt"
import      "core:math"
import      "core:math/linalg"
import path "core:path/filepath"
import      "core:strings"

import gl "vendor:OpenGL"

SHOW_SHADER_DIAGNOSTICS :: #config(shader_diagnostics, true)

Handle :: u32

Shader :: struct
{
    id: Handle,
}

current_shader: Shader

shader_diagnostic :: proc(shader_handle: u32, buffer: []byte) -> (ok: bool)
{
    for &value in buffer {
        value = 0
    }

    sucess: i32
    gl.GetShaderiv(shader_handle, gl.COMPILE_STATUS, &sucess)
    ok = bool(sucess)

when SHOW_SHADER_DIAGNOSTICS 
{
    if ok {
        fmt.println("Successful compilation of shader.")
    }
    else {
        gl.GetShaderInfoLog(shader_handle, i32(len(buffer)), nil, raw_data(buffer))
        fmt.eprintf("Error: compilation of shader failed.\n%s", buffer)
    }

}
    return ok
}

@(private)
shader_init :: proc(shader_path: string) -> (shader: Handle, ok: bool)
{
    dir, filename := path.split(shader_path)
    shader_type   := u32(gl.VERTEX_SHADER)
    prefix        := filename[:2]
    if strings.compare(prefix, "fs") == 0 {
        shader_type = gl.FRAGMENT_SHADER
    }

    file, err := os.open(shader_path)
    {
        defer os.close(file)
        if err != nil {
            fmt.eprintfln("Could not open %v", shader_path)
            return shader, ok
        }

        file_contents, read_ok := os.read_entire_file_from_handle(file)
        defer delete(file_contents) 
        if !read_ok {
            fmt.eprintfln("Could not read file contents of %v", shader_path)
            return shader, ok
        }

        cstr := cstring(raw_data(file_contents))
        shader = gl.CreateShader(shader_type)
        gl.ShaderSource(shader, 1, &cstr, nil)
        gl.CompileShader(shader)
    }

    buffer: [256]byte = ---
    when SHOW_SHADER_DIAGNOSTICS 
    {
        fmt.printf("Diagnostics for %v: ", shader_path)
    }
    shader_diagnostic(shader, buffer[:]) or_return

    ok = true
    return shader, ok
}

/*
 * Creates a shader program by compiling and linking the .glsl files inside the specified folder,
   the folder must contain two files, with each prefixed with its type: vs_foo.glsl, fs_foo.glsl

 * Usage: shader_create("shader_folder")
 */
@(require_results)
shader_create :: proc(shader_folder: string) -> (shader: Shader, ok: bool)
{
    shader_path := strings.join({"res/shaders/", shader_folder, "/"}, "")
    defer delete(shader_path)

    directory   := path.dir(shader_path)
    glob        := path.join({directory, "*.glsl"})
    defer delete(glob)

    shader_names, err := path.glob(glob)
    if err != nil {
        return {}, false
    }
    
    if len(shader_names) != 2 {
        return {}, false
    }

    shader.id    = gl.CreateProgram()

    compiled_shaders: [2]Handle
    for &handle, i in compiled_shaders {
        handle = shader_init(shader_names[i]) or_return
        gl.AttachShader(shader.id, handle)
    }

    defer for handle in compiled_shaders {
        gl.DeleteShader(handle)
    }

    success: i32
    gl.LinkProgram(shader.id)

    buffer: [256]u8
    gl.GetProgramiv(shader.id, gl.LINK_STATUS, &success);
    if bool(success) {
        when SHOW_SHADER_DIAGNOSTICS
        {
            fmt.printfln("Successful linkage of shader program")
        }
    }
    else {
        buffer = 0
        when SHOW_SHADER_DIAGNOSTICS
        {
            gl.GetProgramInfoLog(shader.id, len(buffer), nil, raw_data(buffer[:]));
            fmt.eprintf("Error: could not link shader program.\n%s", buffer)
        }
        return
    }

    ok = true

    return shader, ok
}

shader_use :: #force_inline proc "contextless" (shader: Shader)
{
    gl.UseProgram(shader.id)
    current_shader = shader
}

shader_delete :: #force_inline proc "contextless" (shader: Shader)
{
    gl.DeleteShader(shader.id)
}

shader_uniform_set_int :: #force_inline proc "contextless" (name: cstring, value: i32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform1i(uniform_location, value)
    return ok
}

shader_uniform_set_float :: #force_inline proc "contextless" (name: cstring, value: f32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform1f(uniform_location, value)
    return ok
}

shader_uniform_set_vector3_f32 :: #force_inline proc "contextless" (name: cstring, value: linalg.Vector3f32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform3f(uniform_location, value.x, value.y, value.z)
    return ok
}

shader_uniform_set_vector3_f64 :: #force_inline proc "contextless" (name: cstring, value: linalg.Vector3f64) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform3d(uniform_location, value.x, value.y, value.z)
    return ok
}

shader_uniform_set_matrix4_f32 :: #force_inline proc "contextless" (name: cstring, value: ^linalg.Matrix4f32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.UniformMatrix4fv(uniform_location, 1, gl.FALSE, &value[0, 0])
    return ok
}

shader_uniform_set_matrix4_f64 :: #force_inline proc "contextless" (name: cstring, value: ^linalg.Matrix4f64) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.UniformMatrix4dv(uniform_location, 1, gl.FALSE, &value[0, 0])
    return ok
}

shader_uniform_set_vector3 :: proc{
    shader_uniform_set_vector3_f32,
    shader_uniform_set_vector3_f64,
}

shader_uniform_set_matrix4 :: proc{
    shader_uniform_set_matrix4_f32,
    shader_uniform_set_matrix4_f64,
}

shader_uniform_set :: proc{
    shader_uniform_set_int,
    shader_uniform_set_float,
    shader_uniform_set_vector3_f32,
    shader_uniform_set_vector3_f64,
    shader_uniform_set_matrix4_f32,
    shader_uniform_set_matrix4_f64,
}
