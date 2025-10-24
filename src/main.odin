package learn_opengl

import "core:c"
import "core:fmt"
import "core:math"

import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"

import glw "gl_wrapper"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

WINDOW_NAME           :: "Leaning OpenGl"
WINDOW_DEFAULT_WIDTH  :: 800
WINDOW_DEFAULT_HEIGHT :: 600

state := struct {
    percentage: f32
}{
    percentage = 0.2
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
    
    if glfw.GetKey(window_handle, glfw.KEY_DOWN) == glfw.PRESS {
        state.percentage -= 0.001
    }
    else if glfw.GetKey(window_handle, glfw.KEY_UP) == glfw.PRESS {
        state.percentage += 0.001
    }
}

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

    shader, ok := glw.shader_create("res/shaders/vs_basic.glsl", "res/shaders/fs_basic.glsl")
    if !ok {
        return
    }
    glw.shader_use(shader)

    vertices := [?]f32{
        // positions       // colors        // texture coords
         0.5,  0.5, 0.0,   1.0, 0.0, 0.0,   1.0, 1.0,   // top right
         0.5, -0.5, 0.0,   0.0, 1.0, 0.0,   1.0, 0.0,   // bottom right
        -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,   0.0, 0.0,   // bottom lett
        -0.5,  0.5, 0.0,   1.0, 1.0, 0.0,   0.0, 1.0    // top left
    }

    vertex_indices := [?]u32{
        0, 1, 3,
        3, 2, 1
    }

    // texture_coordinates := [?]f32{
    //     0.0, 0.0,  // lower-left corner  
    //     1.0, 0.0,  // lower-right corner
    //     0.5, 1.0 
    // }
    stbi.set_flip_vertically_on_load(c.int(true))

    image_name: cstring = "res/images/container.jpg";
    width, height, number_of_channels: c.int = ---, ---, ---
    data := stbi.load(image_name, &width, &height, &number_of_channels, 0)
    if data == nil {
        fmt.eprintfln("Could not load %v", image_name)
        return
    }
    // defer stbi.image_free(data) // Leaking is fine, let OS clean stuff

    texture: u32 = ---
    gl.GenTextures(1, &texture)
    // gl.ActiveTexture(gl.TEXTURE0) // Default texture unit
    gl.BindTexture(gl.TEXTURE_2D, texture)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.MIRRORED_REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.MIRRORED_REPEAT);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
    gl.GenerateMipmap(gl.TEXTURE_2D)

    image_name = "res/images/awesomeface.png"
    data = stbi.load(image_name, &width, &height, &number_of_channels, 0)
    if data == nil {
        fmt.eprintfln("Could not load %v", image_name)
        return
    }

    gl.GenTextures(1, &texture)
    gl.ActiveTexture(gl.TEXTURE1)
    gl.BindTexture(gl.TEXTURE_2D, texture)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.REPEAT);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
    gl.GenerateMipmap(gl.TEXTURE_2D)

    glw.shader_uniform_set(shader, "texture1", 0)
    glw.shader_uniform_set(shader, "texture2", 1)

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

    stride :: 8 * size_of(f32)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, stride, 0)
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, stride, 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)

    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, stride, 6 * size_of(f32))
    gl.EnableVertexAttribArray(2)

    for !glfw.WindowShouldClose(window_handle) {
        gl.Clear(gl.COLOR_BUFFER_BIT)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        glw.shader_uniform_set(shader, "u_percent", state.percentage)
        process_input(window_handle)

        glfw.PollEvents()
        glfw.SwapBuffers(window_handle)
    }
}
