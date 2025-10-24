package learn_opengl

import "core:c"
import "core:fmt"
import "core:math"

import gl "vendor:OpenGL"
import "vendor:glfw"

import glw "gl_wrapper"

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


    // uniform_name: cstring  = "ourColor"
    // vertex_color_location := gl.GetUniformLocation(shader_program, uniform_name)
    // if vertex_color_location == -1 {
    //     fmt.eprintfln("Error: could not retrieve uniform of name '%v'", uniform_name)
    //     return
    // }

    // gl.UseProgram(shader_program)
    shader, ok := glw.shader_create("res/vs_basic.glsl", "res/fs_basic.glsl")
    if !ok {
        return
    }
    glw.shader_use(shader)

    number_of_attributes :: 2
    values_per_attribute :: 3
    vertices := [?]f32{
        // positions         // colors
         0.5, -0.5, 0.0,  1.0, 0.0, 0.0,   // bottom right
        -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,   // bottom let
         0.0,  0.5, 0.0,  0.0, 0.0, 1.0    // top
    }

    vertex_indices := [?]u32{
        0, 1, 2
    }

    vao, vbo, ebo: u32 = ---, ---, ---
    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    defer {
        gl.DeleteVertexArrays(1, &vao)
        gl.DeleteBuffers(1, &vbo)
        gl.DeleteBuffers(1, &ebo)
        glw.shader_delete(shader)
    }

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(vertex_indices), &vertex_indices, gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, values_per_attribute, gl.FLOAT, gl.FALSE, number_of_attributes * values_per_attribute * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, values_per_attribute, gl.FLOAT, gl.FALSE, number_of_attributes * values_per_attribute * size_of(f32), 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)
    // number_of_attributes: i32 = ---
    // gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &number_of_attributes)
    // fmt.printfln("Max number of attributes: %v", number_of_attributes)

    for !glfw.WindowShouldClose(window_handle) {
        gl.Clear(gl.COLOR_BUFFER_BIT)

        // time        := glfw.GetTime()
        // green_value := f32(math.sin(time / 2)) + 0.5
        // gl.Uniform4f(vertex_color_location, 0, green_value, 0, 1)

        gl.DrawElements(gl.TRIANGLES, 3, gl.UNSIGNED_INT, nil)

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
