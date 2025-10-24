package gl_wrapper

import "core:os"
import "core:fmt"
import gl "vendor:OpenGL"

Shader_ID :: u32

Shader :: struct
{
    id: Shader_ID,
}

shader_diagnostic :: proc(shader_handle: u32, buffer: []byte) -> (ok: bool)
{
    for &value in buffer {
        value = 0
    }

    sucess: i32
    gl.GetShaderiv(shader_handle, gl.COMPILE_STATUS, &sucess)
    ok = bool(sucess)

    if ok {
        fmt.println("Successful compilation of shader.")
    }
    else {
        gl.GetShaderInfoLog(shader_handle, i32(len(buffer)), nil, raw_data(buffer))
        fmt.eprintf("Error: compilation of shader failed.\n%s", buffer)
    }

    return ok
}

@(require_results)
shader_create :: proc(vertex_shader_path, fragment_shader_path: string) -> (shader: Shader, ok: bool)
{
    vertex_shader, fragment_shader: Shader_ID
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
    fmt.print("Diagnostics for vertex shader:\n\t")
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
    fmt.print("Diagnostics for fragment shader:\n\t")
    shader_diagnostic(fragment_shader, buffer[:]) or_return

    shader.id = gl.CreateProgram()

    success: i32
    gl.AttachShader(shader.id, vertex_shader)
    gl.AttachShader(shader.id, fragment_shader)
    gl.LinkProgram(shader.id)

    gl.GetProgramiv(shader.id, gl.LINK_STATUS, &success);
    if bool(success) {
        fmt.printfln("Successful linkage of shader program")
    }
    else {
        buffer = 0
        gl.GetProgramInfoLog(shader.id, len(buffer), nil, raw_data(buffer[:]));
        fmt.eprintf("Error: could not link shader program.\n%s", buffer)
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
}

shader_delete :: proc "contextless" (shader: Shader)
{
    gl.DeleteShader(shader.id)
}

shader_uniform_set_int :: proc "contextless" (shader: Shader, name: cstring, value: i32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform1i(uniform_location, value)
    return ok
}

shader_uniform_set_float :: proc "contextless" (shader: Shader, name: cstring, value: f32) -> (ok: bool)
{
    uniform_location := gl.GetUniformLocation(shader.id, name)
    ok                = uniform_location != -1
    gl.Uniform1f(uniform_location, value)
    return ok
}

shader_uniform_set :: proc{
    shader_uniform_set_int,
    shader_uniform_set_float,
}
