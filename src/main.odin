package learn_opengl

import "core:c"
import "core:fmt"

import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

WINDOW_NAME           :: "Leaning OpenGl"
WINDOW_DEFAULT_WIDTH  :: 800
WINDOW_DEFAULT_HEIGHT :: 600

main :: proc() 
{
    if !bool(glfw.Init()) {
        fmt.eprintln("GLFW has failed to load.")
        return
    }

    window_handle := glfw.CreateWindow(
        WINDOW_DEFAULT_WIDTH,
        WINDOW_DEFAULT_HEIGHT,
        WINDOW_NAME,
        nil,
        nil,
    )

    defer {
        glfw.Terminate()
        glfw.DestroyWindow(window_handle)
    }

    if window_handle == nil {
        fmt.eprintln("Failed to create GLFW window.")
        return
    }

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    glfw.MakeContextCurrent(window_handle)
    gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

    glfw.SetFramebufferSizeCallback(window_handle, set_framebuffer_size_callback)

    gl.Viewport(0, 0, WINDOW_DEFAULT_WIDTH, WINDOW_DEFAULT_HEIGHT)
    gl.ClearColor(0.2, 0.3, 0.3, 1.0)

    vs_source: cstring = `
        #version 330 core
        layout (location = 0) in vec3 aPos;

        void main()
        {
            gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        }
    `

    vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
    gl.ShaderSource(vertex_shader, 1, &vs_source, nil)
    gl.CompileShader(vertex_shader)

    success:     i32 = ---
    log_buffer: [256]c.char
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)

    if bool(success) {
        fmt.println("Successful compilation of vertex shader.")
    }
    else {
        gl.GetShaderInfoLog(vertex_shader, len(log_buffer), nil, raw_data(log_buffer[:]))
        fmt.eprintfln("Error: compilation of vertex shader failed.\n%s", log_buffer)
        return
    }

    fs_source: cstring = `
        #version 330 core
        out vec4 FragColor;

        void main()
        {
            FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
        }
    `

    fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(fragment_shader, 1, &fs_source, nil)
    gl.CompileShader(fragment_shader)

    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)

    if bool(success) {
        fmt.println("Successful compilation of fragment shader.")
    }
    else {
        gl.GetShaderInfoLog(fragment_shader, len(log_buffer), nil, raw_data(log_buffer[:]))
        fmt.eprintf("Error: compilation of fragment shader failed.\n%s", log_buffer)
        return
    }

    shader_program := gl.CreateProgram()
    gl.AttachShader(shader_program, vertex_shader)
    gl.AttachShader(shader_program, fragment_shader)
    gl.LinkProgram(shader_program)

    gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success);
    if bool(success) {
        fmt.printfln("Successful linkage of shader program")
    }
    else {
        gl.GetProgramInfoLog(shader_program, len(log_buffer), nil, raw_data(log_buffer[:]));
        fmt.eprintf("Error: could not link shader program.\n%s", log_buffer)
        return
    }
    
    gl.DeleteShader(vertex_shader)
    gl.DeleteShader(fragment_shader)

    gl.UseProgram(shader_program)

    values_per_attribute :: 3
    vertices := [?]f32{
        // -0.5, -0.5, 0.0,
        //  0.5, -0.5, 0.0,
        //  0.0,  0.5, 0.0

         // first triangle
         0.5,  0.5, 0.0,  // top right
         0.5, -0.5, 0.0,  // bottom right
        -0.5, -0.5, 0.0,  // bottom left
        -0.5,  0.5, 0.0   // top left
    }

    vertex_indices := [?]u32{
        0, 1, 3,
        1, 2, 3
    }

    vao, vbo, ebo: u32 = ---, ---, ---
    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    defer {
        gl.DeleteVertexArrays(1, &vao)
        gl.DeleteBuffers(1, &vbo)
        gl.DeleteBuffers(1, &ebo)
        gl.DeleteProgram(shader_program)
    }

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(vertex_indices), &vertex_indices, gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, values_per_attribute, gl.FLOAT, gl.FALSE, values_per_attribute * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    for !glfw.WindowShouldClose(window_handle) {
        gl.Clear(gl.COLOR_BUFFER_BIT)

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        process_input(window_handle)

        glfw.PollEvents()
        glfw.SwapBuffers(window_handle)
    }
}

set_framebuffer_size_callback :: proc "c" (window_handle: glfw.WindowHandle, width, height: i32) 
{
    gl.Viewport(0, 0, width, height)
}

process_input :: proc "c" (window_handle: glfw.WindowHandle) 
{
    if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) == glfw.PRESS {
        glfw.SetWindowShouldClose(window_handle, true)
    }
}
