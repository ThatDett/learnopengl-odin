package learn_opengl

import "core:c"
import "core:fmt"

import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

WINDOW_NAME :: "Leaning OpenGl"
WINDOW_DEFAULT_WIDTH :: 800
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

    glfw.SetFramebufferSizeCallback(
        window_handle,
        cast(glfw.FramebufferSizeProc)(set_framebuffer_size_callback),
    )

    gl.Viewport(0, 0, WINDOW_DEFAULT_WIDTH, WINDOW_DEFAULT_HEIGHT)
    gl.ClearColor(0.2, 0.3, 0.3, 1.0)

    for !glfw.WindowShouldClose(window_handle) {
        gl.Clear(gl.COLOR_BUFFER_BIT)

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
