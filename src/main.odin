package learn_opengl

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"

import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"

import glw "gl_wrapper"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

WINDOW_NAME         :: "Leaning OpenGl"
WINDOW_DEFAULT_SIZE :: Dimensions{1280, 720}

CAMERA_MAX_FOV :: 45
CAMERA_MIN_FOV :: 1

UP       :: linalg.Vector3f32{ 0,  1,  0}
DOWN     :: linalg.Vector3f32{ 0, -1,  0}
RIGHT    :: linalg.Vector3f32{ 1,  0,  0}
LEFT     :: linalg.Vector3f32{-1,  0,  0}
OUTWARDS :: linalg.Vector3f32{ 0,  0,  1}
TOWARDS  :: linalg.Vector3f32{ 0,  0, -1}

Dimensions :: struct
{
    width, height: f32
}

Movement_Mode :: enum
{
    walk,
    fly
}

Camera :: struct
{
    using position: linalg.Vector3f32,
    target:         linalg.Vector3f32,
    direction:      linalg.Vector3f32,
    up:             linalg.Vector3f32,
    right:          linalg.Vector3f32,

    movement_mode: Movement_Mode,
    
    fov:   f32,
    speed: f32,
    yaw:   f32,
    pitch: f32,
}

Mouse :: struct
{
    using position:    linalg.Vector2f32,
    previous_position: linalg.Vector2f32,

    sensitivity:        f32,
    scroll_sensitivity: f32
}

global := struct
{
    camera:        Camera,
    mouse:         Mouse,
    viewport_size: Dimensions,
    dt:            f64,

    first_mouse_callback:    bool,
}{
    viewport_size = WINDOW_DEFAULT_SIZE,
    first_mouse_callback    = true
}

set_framebuffer_size_callback :: proc "c" (window_handle: glfw.WindowHandle, width, height: i32) 
{
    global.viewport_size = {f32(width), f32(height)}
    gl.Viewport(0, 0, width, height)
}

scroll_callback :: proc "c" (window_handle: glfw.WindowHandle, x_offset, y_offset: f64)
{
    using global.camera
    fov -= f32(y_offset) * global.mouse.scroll_sensitivity
    fov  = math.clamp(fov, CAMERA_MIN_FOV, CAMERA_MAX_FOV)
}

mouse_callback :: proc "c" (window_handle: glfw.WindowHandle, mouse_x, mouse_y: f64)
{
    using global.mouse
    position        = {f32(mouse_x), f32(mouse_y)}
    if global.first_mouse_callback {
        previous_position = position
        global.first_mouse_callback = false
    }
    delta_position := type_of(position){
        x - previous_position.x,
      -(y - previous_position.y)
    }

    delta_position      *= sensitivity
    global.camera.yaw   += delta_position.x
    global.camera.pitch += delta_position.y

    global.camera.pitch = math.clamp(global.camera.pitch, -89, 89)
    global.camera.direction = {
        math.cos(math.to_radians(global.camera.yaw)) * math.cos(math.to_radians(global.camera.pitch)),
        math.sin(math.to_radians(global.camera.pitch)),
        math.sin(math.to_radians(global.camera.yaw)) * math.cos(math.to_radians(global.camera.pitch)),
    }

    global.camera.direction = linalg.normalize(global.camera.direction)
    previous_position   = position
}

process_input :: proc "c" (window_handle: glfw.WindowHandle) 
{
    if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) == glfw.PRESS {
        glfw.SetWindowShouldClose(window_handle, true)
    }

    camera_speed := global.camera.speed * f32(global.dt)
    direction    := global.camera.direction
    if (global.camera.movement_mode == Movement_Mode.fly)
    {
        direction = linalg.normalize(type_of(global.camera.position){global.camera.direction.x, 0, global.camera.direction.z})
    }

    if glfw.GetKey(window_handle, glfw.KEY_W) == glfw.PRESS {
        global.camera.position += camera_speed * direction
    }
    if glfw.GetKey(window_handle, glfw.KEY_S) == glfw.PRESS {
        global.camera.position -= camera_speed * direction
    }
    if glfw.GetKey(window_handle, glfw.KEY_D) == glfw.PRESS {
        global.camera.position += camera_speed * linalg.normalize(linalg.cross(global.camera.direction, global.camera.up))
    }
    if glfw.GetKey(window_handle, glfw.KEY_A) == glfw.PRESS {
        global.camera.position -= camera_speed * linalg.normalize(linalg.cross(global.camera.direction, global.camera.up))
    }
}

main :: proc() 
{
    if !bool(glfw.Init()) {
        fmt.eprintln("GLFW has failed to load.")
        return
    }

    window_handle := glfw.CreateWindow(
        i32(global.viewport_size.width),
        i32(global.viewport_size.height),
        WINDOW_NAME,
        nil,
        nil,
    )

    glfw.SetInputMode(window_handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
    glfw.SetWindowPos(window_handle, 0, 32)

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
    glfw.SetCursorPosCallback(window_handle,       mouse_callback)
    glfw.SetScrollCallback(window_handle,          scroll_callback)

    gl.Viewport(0, 0, i32(global.viewport_size.width), i32(global.viewport_size.height))
    gl.ClearColor(0.2, 0.3, 0.3, 1.0)
    
    ok: bool = ---

    lighting_shader, light_source_shader: glw.Shader = ---, ---
    lighting_shader, ok = glw.shader_create("res/shaders/vs_basic.glsl", "res/shaders/fs_basic.glsl")
    if !ok {
        return
    }
    
    glw.shader_use(lighting_shader)
    light_color := linalg.Vector3f32{1, 1, 1}
    glw.shader_uniform_set_vec3("object_color", {1, 0.5, 0.31})
    glw.shader_uniform_set_vec3("light_color", light_color)

    light_source_shader, ok = glw.shader_create("res/shaders/vs_white.glsl", "res/shaders/fs_white.glsl")

    light_pos := linalg.Vector3f32{}

    glw.shader_use(light_source_shader)
    glw.shader_uniform_set_vec3("light_color", light_color)

    vertices := [?]f32{
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
         0.5, -0.5, -0.5,  0.0,  0.0, -1.0, 
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0, 
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0, 
        -0.5,  0.5, -0.5,  0.0,  0.0, -1.0, 
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0, 

        -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,
         0.5, -0.5,  0.5,  0.0,  0.0, 1.0,
         0.5,  0.5,  0.5,  0.0,  0.0, 1.0,
         0.5,  0.5,  0.5,  0.0,  0.0, 1.0,
        -0.5,  0.5,  0.5,  0.0,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,

        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,
        -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,
        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,

         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,
         0.5,  0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5,  0.5,  1.0,  0.0,  0.0,
         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,

        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
         0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
        -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,

        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
         0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0
    }

    // cube_positions := [?]linalg.Vector3f32{
    //     { 0.0,  0.0,  0.0, },
    //     { 2.0,  5.0, -15.0,}, 
    //     {-1.5, -2.2, -2.5, }, 
    //     {-3.8, -2.0, -12.3,},  
    //     { 2.4, -0.4, -3.5, }, 
    //     {-1.7,  3.0, -7.5, }, 
    //     { 1.3, -2.0, -2.5, }, 
    //     { 1.5,  2.0, -2.5, },
    //     { 1.5,  0.2, -1.5, },
    //     {-1.3,  1.0, -1.5  },
    // }

    vertex_indices := [?]u32{
        0, 1, 3,
        3, 2, 1
    }

    stbi.set_flip_vertically_on_load(c.int(true))

    width, height, number_of_channels: c.int = ---, ---, ---
    image_name  := cstring("res/images/container.jpg");
    data        := stbi.load(image_name, &width, &height, &number_of_channels, 0)
    if data == nil {
        fmt.eprintfln("Could not load %v", image_name)
        return
    }
    // defer stbi.image_free(data) // Leaking is fine, let OS clean stuff

    // texture: u32 = ---
    // gl.GenTextures(1, &texture)
    // gl.ActiveTexture(gl.TEXTURE0) // Default texture unit
    // gl.BindTexture(gl.TEXTURE_2D, texture)

    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.MIRRORED_REPEAT);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.MIRRORED_REPEAT);
    //
    // gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
    // gl.GenerateMipmap(gl.TEXTURE_2D)

    image_name = "res/images/awesomeface.png"
    data       = stbi.load(image_name, &width, &height, &number_of_channels, 0)
    if data == nil {
        fmt.eprintfln("Could not load %v", image_name)
        return
    }

    // gl.GenTextures(1, &texture)
    // gl.ActiveTexture(gl.TEXTURE1)
    // gl.BindTexture(gl.TEXTURE_2D, texture)
    //
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.REPEAT);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.REPEAT);
    //
    // gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
    // gl.GenerateMipmap(gl.TEXTURE_2D)
    //
    // glw.shader_uniform_set(lighting_shader, "texture1", 0)
    // glw.shader_uniform_set(lighting_shader, "texture2", 1)

    light_vao, vao, vbo, ebo: glw.Handle = ---, ---, ---, ---
    gl.GenVertexArrays(1, &light_vao)
    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    defer {
        gl.DeleteVertexArrays(1, &light_vao)
        gl.DeleteVertexArrays(1, &vao)
        gl.DeleteBuffers(1, &vbo)
        gl.DeleteBuffers(1, &ebo)
        glw.shader_delete(lighting_shader)
        glw.shader_delete(light_source_shader)
    }

    gl.BindVertexArray(light_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    stride: i32 = 6 * size_of(f32)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, stride, 0)
    gl.EnableVertexAttribArray(0)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

    // gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    // gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(vertex_indices), &vertex_indices, gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, stride, 0)
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, stride, 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)

    // gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, stride, 3 * size_of(f32))
    // gl.EnableVertexAttribArray(1)

    // gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, stride, 3 * size_of(f32))
    // gl.EnableVertexAttribArray(1)

    model_mat:      linalg.Matrix4x4f32 = --- 
    view_mat:       linalg.Matrix4x4f32 = --- 
    projection_mat: linalg.Matrix4x4f32 = --- 

    gl.Enable(gl.DEPTH_TEST)

    //Init camera
    {
        using global.camera
        position  = {0, 0, 3}
        direction = linalg.normalize(position - target)

        fov   = 45
        speed = 5
        yaw   = -90
    }
    //Init mouse
    {
        using global.mouse
        sensitivity        = 0.05
        scroll_sensitivity = 3
    }
    
    // model_mat = linalg.MATRIX4F32_IDENTITY
    draw_cube :: proc()
    {
        gl.DrawArrays(gl.TRIANGLES, 0, 36)
    }

    last_frame: f64
    for !glfw.WindowShouldClose(window_handle) {
        current_time := glfw.GetTime()
        global.dt     = current_time - last_frame
        last_frame    = current_time

        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        {
            using global.camera
            right          = linalg.normalize(linalg.cross(UP, direction))
            up             = linalg.cross(direction, right) // Inputs are already normalized
            view_mat       = linalg.matrix4_look_at_f32(position, position + direction, up)
            projection_mat = linalg.matrix4_perspective_f32(
                math.to_radians_f32(CAMERA_MAX_FOV), 
                global.viewport_size.width / global.viewport_size.height,
                0.1, 
                100
            )
        }

        glw.shader_use(lighting_shader)
        glw.shader_uniform_set("projection", &projection_mat)
        glw.shader_uniform_set("view",       &view_mat)

        light_pos = global.camera.position + global.camera.direction * f32(CAMERA_MAX_FOV)/global.camera.fov + {}
        model_mat = linalg.MATRIX4F32_IDENTITY
        // model_mat = linalg.matrix4_translate_f32({}) * model_mat
        model_mat = linalg.matrix4_scale_f32({0.5, 0.5, 0.5}) * model_mat
        glw.shader_uniform_set("model",      &model_mat)
        // glw.shader_uniform_set("camera_pos", global.camera.position)
        glw.shader_uniform_set("light_pos",  light_pos)

        gl.BindVertexArray(vao)
        draw_cube()

        glw.shader_use(light_source_shader)
        glw.shader_uniform_set("projection", &projection_mat)

        glw.shader_uniform_set("view",       &view_mat)
        model_mat = linalg.MATRIX4F32_IDENTITY
        model_mat = linalg.matrix4_scale_f32({0.5, 0.5, 0.5}) * model_mat
        model_mat = linalg.matrix4_translate_f32(light_pos) * model_mat
        glw.shader_uniform_set("model",      &model_mat)


        gl.BindVertexArray(light_vao)
        draw_cube()

        // for cube_position, i in cube_positions {
        //     model := linalg.MATRIX4F32_IDENTITY
        //     model = linalg.matrix4_translate_f32(cube_position) * model
        //     glw.shader_uniform_set(lighting_shader, "model", &model)
        //
        //     gl.DrawArrays(gl.TRIANGLES, 0, 36)
        // }

        // gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

        process_input(window_handle)

        glfw.SwapBuffers(window_handle)
        glfw.PollEvents()
    }
}
