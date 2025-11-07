package gl_wrapper

import "core:os"
import "core:fmt"
import "core:math"
import "core:math/linalg"

import gl "vendor:OpenGL"

SHOW_SHADER_DIAGNOSTICS :: #config(shader_diagnostics, true)
// SHOW_SHADER_DIAGNOSTICS :: false

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

@(require_results)
shader_create :: proc(vertex_shader_path, fragment_shader_path: string) -> (shader: Shader, ok: bool)
{
    vertex_shader, fragment_shader: Handle
    file, err := os.open(vertex_shader_path)
    {
        defer os.close(file)
        if err != nil {
            fmt.eprintfln("Could not open %v", vertex_shader_path)
            return
        }

        file_contents, read_ok := os.read_entire_file_from_handle(file)
        defer delete(file_contents) 
        if !read_ok {
            fmt.eprintfln("Could not read file contents of %v", vertex_shader_path)
            return
        }

        cstr := cstring(raw_data(file_contents))
        vertex_shader = gl.CreateShader(gl.VERTEX_SHADER)
        gl.ShaderSource(vertex_shader, 1, &cstr, nil)
        gl.CompileShader(vertex_shader)
    }

    buffer: [256]byte = ---
    when SHOW_SHADER_DIAGNOSTICS 
    {
        fmt.printf("Diagnostics for %v: ", vertex_shader_path)
    }
    shader_diagnostic(vertex_shader, buffer[:]) or_return

    file, err = os.open(fragment_shader_path)
    {
        defer os.close(file)
        if err != nil {
            fmt.eprintfln("Could not open %v", fragment_shader_path)
            return
        }

        file_contents, read_ok := os.read_entire_file_from_handle(file)
        defer delete(file_contents) 
        if !read_ok {
            fmt.eprintfln("Could not read file contents of %v", fragment_shader_path)
            return
        }

        cstr := cstring(raw_data(file_contents))
        fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER)
        gl.ShaderSource(fragment_shader, 1, &cstr, nil)
        gl.CompileShader(fragment_shader)
    }

    // fmt.printfln("%v", buffer)
    when SHOW_SHADER_DIAGNOSTICS 
    {
        fmt.printf("Diagnostics for %v: ", fragment_shader_path)
    }
    shader_diagnostic(fragment_shader, buffer[:]) or_return

    shader.id = gl.CreateProgram()

    success: i32
    gl.AttachShader(shader.id, vertex_shader)
    gl.AttachShader(shader.id, fragment_shader)
    gl.LinkProgram(shader.id)


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

    gl.DeleteShader(vertex_shader)
    gl.DeleteShader(fragment_shader)
    return shader, ok
}

shader_use :: proc "contextless" (shader: Shader)
{
    gl.UseProgram(shader.id)
    current_shader = shader
}

shader_delete :: proc "contextless" (shader: Shader)
{
    gl.DeleteShader(shader.id)
}

shader_uniform_set_int :: proc "contextless" (name: cstring, value: i32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform1i(uniform_location, value)
    return ok
}

shader_uniform_set_float :: proc "contextless" (name: cstring, value: f32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform1f(uniform_location, value)
    return ok
}

shader_uniform_set_vec3_f32 :: proc "contextless" (name: cstring, value: linalg.Vector3f32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform3f(uniform_location, value.x, value.y, value.z)
    return ok
}

shader_uniform_set_vec3_f64 :: proc "contextless" (name: cstring, value: linalg.Vector3f64) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform3d(uniform_location, value.x, value.y, value.z)
    return ok
}

shader_uniform_set_matrix4_f32 :: proc "contextless" (name: cstring, value: ^linalg.Matrix4f32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.UniformMatrix4fv(uniform_location, 1, gl.FALSE, &value[0, 0])
    return ok
}

shader_uniform_set_matrix4_f64 :: proc "contextless" (name: cstring, value: ^linalg.Matrix4f64) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(current_shader.id, name)
    ok                = uniform_location != -1
    gl.UniformMatrix4dv(uniform_location, 1, gl.FALSE, &value[0, 0])
    return ok
}

shader_uniform_set_vec3 :: proc{
    shader_uniform_set_vec3_f32, 
    shader_uniform_set_vec3_f64 
}

shader_uniform_set_matrix4 :: proc{
    shader_uniform_set_matrix4_f32,
    shader_uniform_set_matrix4_f64
}
shader_uniform_set :: proc
{
    shader_uniform_set_int,
    shader_uniform_set_float,
    shader_uniform_set_vec3_f32,
    shader_uniform_set_vec3_f64,
    shader_uniform_set_matrix4_f32, 
    shader_uniform_set_matrix4_f64, 
}
