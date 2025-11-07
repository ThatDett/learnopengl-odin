package learn_opengl

import     "core:c"
import     "core:fmt"
import     "core:math"
import alg "core:math/linalg"
import     "core:log" 
import     "core:os"
import     "core:encoding/json"

import      "vendor:glfw"
import gl   "vendor:OpenGL"
import stbi "vendor:stb/image"

import glw        "gl_wrapper"
import            "dependencies:imgui"
import imgui_gl   "dependencies:imgui/imgui_impl_opengl3"
import imgui_glfw "dependencies:imgui/imgui_impl_glfw"
// import imgui      "external/odin-imgui"
// import imgui_gl   "external/odin-imgui/impl/opengl"
// import imgui_glfw "external/odin-imgui/impl/glfw"

/////////////// - Enums - ///////////////
Key_State :: enum u8
{
    nil,
    pressed,
    held,
    released
}

Movement_Mode :: enum u8
{
    walk,
    fly,
}

Mouse_Mode :: enum u8
{
    locked,
    free,
}

/////////////// - Structs - ///////////////
Vector2 :: alg.Vector2f32
Vector3 :: alg.Vector3f32

Dimensions :: struct
{
    width, height: f32
}

Camera :: struct
{
    using position: Vector3,
    target:         Vector3,
    direction:      Vector3,
    up:             Vector3,
    right:          Vector3,

    movement_mode: Movement_Mode,
    
    fov:   f32,
    speed: f32,
    yaw:   f32,
    pitch: f32,
}

Mouse :: struct
{
    using position:    Vector2,
    previous_position: Vector2,

    mode: Mouse_Mode,

    sensitivity:        f32,
    scroll_sensitivity: f32
}

/////////////// - Constants - ///////////////
PRINT_FPS :: #config(print_fps, false)

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

WINDOW_NAME         :: "Learning OpenGL"
WINDOW_DEFAULT_SIZE :: Dimensions{1366/1, 768/1}

CAMERA_MAX_FOV :: 45
CAMERA_MIN_FOV :: 1

RIGHT    :: Vector3{ 1,  0,  0}
UP       :: Vector3{ 0,  1,  0}
OUTWARDS :: Vector3{ 0,  0,  1}
LEFT     :: -RIGHT
DOWN     :: -UP
TOWARDS  :: -OUTWARDS

/////////////// - Procedures - ///////////////
process_input :: proc(window_handle: glfw.WindowHandle) 
{
    @(static)
    key_pressed_before: [glfw.KEY_LAST + 1]bool
    for key in 0..=glfw.KEY_LAST {
        state := glfw.GetKey(window_handle, cast(c.int)key)

        pressed_now    := (state == glfw.PRESS)
        pressed_before := key_pressed_before[key]

        if pressed_now && !pressed_before {
            global.key_pressed[key] = .pressed
        } else if !pressed_now && pressed_before {
            global.key_pressed[key] = .released
        }
        else if pressed_now && pressed_before {
            global.key_pressed[key] = .held
        }
        else {
            global.key_pressed[key] = nil
        }

        key_pressed_before[key] = pressed_now
    }
}

camera_movement :: proc "contextless" () -> f32
{
    camera_speed := f32(f64(global.camera.speed) * global.dt)
    direction    := global.camera.direction
    if (global.camera.movement_mode == .fly)
    {
        direction = alg.normalize(type_of(global.camera.position){global.camera.direction.x, 0, global.camera.direction.z})
    }

    if key_held(glfw.KEY_W) {
        global.camera.position += camera_speed * direction
    }
    if key_held(glfw.KEY_S) {
        global.camera.position -= camera_speed * direction
    }
    if key_held(glfw.KEY_D) {
        global.camera.position += camera_speed * alg.normalize(alg.cross(global.camera.direction, global.camera.up))
    }
    if key_held(glfw.KEY_A) {
        global.camera.position -= camera_speed * alg.normalize(alg.cross(global.camera.direction, global.camera.up))
    }
    return camera_speed
}

key_pressed :: #force_inline proc "contextless" (key: c.int, caller_location := #caller_location) -> bool
{
    assert_contextless(key >= 0 && key <= glfw.KEY_LAST, "Invalid key", caller_location)
    return global.key_pressed[key] == .pressed
}

key_released :: #force_inline proc "contextless" (key: c.int, caller_location := #caller_location) -> bool
{
    assert_contextless(key >= 0 && key <= glfw.KEY_LAST, "Invalid key", caller_location)
    return global.key_pressed[key] == .released
}

key_held :: #force_inline proc "contextless" (key: c.int, caller_location := #caller_location) -> bool
{
    assert_contextless(key >= 0 && key <= glfw.KEY_LAST, "Invalid key", caller_location)
    return global.key_pressed[key] == .held
}

main :: proc() 
{
    logger_options := log.Options {
        .Level,
        .Line,
        .Procedure
    }
    context.logger = log.create_console_logger(opt = logger_options)

    if !bool(glfw.Init()) {
        desc, error := glfw.GetError()
        fmt.eprintln("GLFW has failed to load: ", error, desc)
        return
    }

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

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

    glfw.MakeContextCurrent(window_handle)
    // glfw.SwapInterval(1) //

    gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

    glfw.SetFramebufferSizeCallback(window_handle, set_framebuffer_size_callback)
    glfw.SetCursorPosCallback(window_handle,       mouse_callback)
    glfw.SetScrollCallback(window_handle,          scroll_callback)

    gl.Viewport(0, 0, i32(global.viewport_size.width), i32(global.viewport_size.height))
    gl.ClearColor(0.2, 0.3, 0.3, 1.0)

    imgui.CHECKVERSION()
    imgui.CreateContext()
    defer imgui.DestroyContext()

    imgui_io := imgui.GetIO()
    imgui_io.ConfigFlags += {.DockingEnable, .NavEnableKeyboard, .NavEnableGamepad}

    imgui.StyleColorsDark()

    imgui_glfw.InitForOpenGL(window_handle, true)
    defer imgui_glfw.Shutdown()

    imgui_gl.Init("#version 330")
    defer imgui_gl.Shutdown()
    
    ok: bool = ---

    lighting_shader, light_source_shader: glw.Shader = ---, ---
    lighting_shader, ok = glw.shader_create("res/shaders/vs_basic.glsl", "res/shaders/fs_basic.glsl")
    if !ok {
        return
    }
    
    glw.shader_use(lighting_shader)
    // glw.shader_uniform_set_vec3("object_color", {1, 0.5, 0.31})
    // glw.shader_uniform_set_vec3("light_color", light_color)

    // glw.shader_uniform_set_vec3_f32( "material.ambient",   {1,   0.5, 0.31})
    // glw.shader_uniform_set_vec3_f32( "material.diffuse",   {1,   0.5, 0.31})
    // glw.shader_uniform_set_vec3_f32( "material.specular",  {0.5, 0.5, 0.50})
    // glw.shader_uniform_set_float("material.shininess", 32)
    // glw.shader_uniform_set_vec3_f32("light.specular",  {1.0, 1.0, 1.0})

    light_source_shader, ok = glw.shader_create("res/shaders/vs_white.glsl", "res/shaders/fs_white.glsl")

    light_pos := Vector3{}

    glw.shader_use(light_source_shader)

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

    // cube_positions := [?]Vector3{
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

    model_mat:      alg.Matrix4x4f32 = --- 
    view_mat:       alg.Matrix4x4f32 = --- 
    projection_mat: alg.Matrix4x4f32 = --- 

    gl.Enable(gl.DEPTH_TEST)

    //Init camera
    {
        using global.camera
        position  = {0, 0, 3}
        direction = alg.normalize(position - target)

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
    
    // model_mat = alg.MATRIX4F32_IDENTITY
    draw_cube :: proc()
    {
        gl.DrawArrays(gl.TRIANGLES, 0, 36)
    }

    seconds_accumulator: f64
    fps_accumulator:     f64
    iteration_count:     u32
    frame_count:         u32
    last_time:           f64

    current_frame:        f64
    last_frame:           f64
    delta_iteration_time: f64

    // glw.shader_uniform_set_vec3_f32( "material.diffuse",   {1,   0.5, 0.31})
    // glw.shader_uniform_set_vec3_f32( "material.specular",  {0.5, 0.5, 0.50})

    imgui_data_filename :: "imgui_data.json"
    default_imgui_data := Imgui_Data{
        material_ambient  = {1,   0.5, 0.31},
        material_diffuse  = {1,   0.5, 0.31},
        material_specular = Vector3(0.5),
        shininess         = f32(32),

        light_color    = Vector3(1),
        light_ambient  = {0.5, 0.5, 0.5},
        light_diffuse  = {0.5, 0.5, 0.5},
        light_specular = {0.5, 0.5, 0.5},
    }

    imgui_data := load_imgui_data(imgui_data_filename, default_imgui_data)

    light_pos = alg.lerp(
        light_pos,
        global.camera.position + global.camera.direction * f32(CAMERA_MAX_FOV)/global.camera.fov + {},
        0.1
    )

    cube_follow_camera: bool = false

    for !glfw.WindowShouldClose(window_handle) {

        current_time         := glfw.GetTime()
        delta_iteration_time  = current_time - last_time
        seconds_accumulator  += delta_iteration_time
        fps_accumulator      += delta_iteration_time
        iteration_count      += 1

        last_time    = current_time

        FPS_PER_SEC :: 60
        if fps_accumulator >= 1.0/FPS_PER_SEC {
            glfw.PollEvents()

            current_frame = current_time
            global.dt     = current_frame - last_frame
            last_frame    = current_time
            process_input(window_handle)
            camera_movement()
            
            if key_pressed(glfw.KEY_ESCAPE) {
                if glfw.GetInputMode(window_handle, glfw.CURSOR) == glfw.CURSOR_DISABLED {
                    glfw.SetInputMode(window_handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
                    global.mouse.mode = .free
                }
                else {
                    glfw.SetInputMode(window_handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
                    global.mouse.mode = .locked
                }
            }

            imgui_gl.NewFrame()
            imgui_glfw.NewFrame()
            imgui.NewFrame()

            if imgui.Begin("Panel") {
                if imgui.Button("Reset") {
                    imgui_data = default_imgui_data
                }
                imgui.SameLine()
                if imgui.Button("Quit") {
                    glfw.SetWindowShouldClose(window_handle, true)
                }
                imgui.ColorEdit3("Material ambient",  &imgui_data.material_ambient)
                imgui.ColorEdit3("Material diffuse",  &imgui_data.material_diffuse)
                imgui.ColorEdit3("Material specular", &imgui_data.material_specular)
                imgui.SliderFloat("Shininess",        &imgui_data.shininess, 0, f32(u32(1) << 10))

                imgui.Spacing()
                imgui.ColorEdit3("Light color",    &imgui_data.light_color)
                imgui.ColorEdit3("Light ambient",  &imgui_data.light_ambient)
                imgui.ColorEdit3("Light diffuse",  &imgui_data.light_diffuse)
                imgui.ColorEdit3("Light specular", &imgui_data.light_specular)

                imgui.Text("FPS: %.2f", imgui_io.Framerate)
                // imgui.Text("FPS: %.2f", iteration_count)
            }
            imgui.End()

            // if imgui.Begin("Other") {
            //     if imgui.Button("Quit") {
            //         glfw.SetWindowShouldClose(window_handle, true)
            //     }
            // }
            // imgui.End()

            display_w, display_h := glfw.GetFramebufferSize(window_handle)
            gl.Viewport(0, 0, display_w, display_h)
            // gl.ClearColor(0, 0, 0, 1)
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

            frame_count     += 1
            fps_accumulator  = 0
            {
                using global.camera
                right          = alg.normalize(alg.cross(UP, direction))
                up             = alg.cross(direction, right) // Inputs are already normalized
                view_mat       = alg.matrix4_look_at_f32(position, position + direction, up)
                projection_mat = alg.matrix4_perspective_f32(
                    math.to_radians_f32(CAMERA_MAX_FOV), 
                    global.viewport_size.width / global.viewport_size.height,
                    0.1, 
                    100
                )
                // coiso := f32(5)
                // projection_mat = alg.matrix_ortho3d_f32(
                //     -coiso, coiso, -coiso, coiso, -coiso, coiso * 4
                // )
            }

            glw.shader_use(lighting_shader)

            // light_color := Vector3{
            //     // cast(f32)math.sin(glfw.GetTime() * 2),
            //     // cast(f32)math.sin(glfw.GetTime() * 0.7),
            //     // cast(f32)math.sin(glfw.GetTime() * 1.3)
            //     1, 1, 1
            // }

            // ambient_color := light_color * (Vector3{} + ambient_factor)
            // diffuse_color := light_color * (Vector3{} + diffuse_factor)
            glw.shader_uniform_set_vec3("material.ambient",    imgui_data.material_ambient)
            glw.shader_uniform_set_vec3("material.diffuse",    imgui_data.material_diffuse)
            glw.shader_uniform_set_vec3("material.specular",   imgui_data.material_specular)
            glw.shader_uniform_set_float("material.shininess", imgui_data.shininess)

            glw.shader_uniform_set_vec3("light.ambient",   imgui_data.light_ambient  * imgui_data.light_color)
            glw.shader_uniform_set_vec3("light.diffuse",   imgui_data.light_diffuse  * imgui_data.light_color)
            glw.shader_uniform_set_vec3("light.specular",  imgui_data.light_specular * imgui_data.light_color)


            glw.shader_uniform_set("projection", &projection_mat)
            glw.shader_uniform_set("view",       &view_mat)

            model_mat = alg.MATRIX4F32_IDENTITY
            model_mat = alg.matrix4_scale_f32({0.5, 0.5, 0.5}) * model_mat
            model_mat = alg.matrix4_translate_f32({2, 0, 2})   * model_mat
            gl.BindVertexArray(vao)

            glw.shader_uniform_set("model",      &model_mat)
            glw.shader_uniform_set("camera_pos", global.camera.position)
            glw.shader_uniform_set("light_pos",  light_pos)

            draw_cube()

            glw.shader_use(light_source_shader)
            glw.shader_uniform_set_vec3_f32("light_color", imgui_data.light_color)

            glw.shader_uniform_set("projection", &projection_mat)
            glw.shader_uniform_set("view",       &view_mat)

            if key_pressed(glfw.KEY_F) {
                cube_follow_camera = !cube_follow_camera
            }

            // thingy_mabob := f32(1 - math.exp(-120 * global.dt))
            model_mat = alg.MATRIX4F32_IDENTITY
            if cube_follow_camera {
                light_pos = alg.lerp(
                    light_pos,
                    global.camera.position + global.camera.direction * f32(CAMERA_MAX_FOV)/global.camera.fov + {},
                    0.1
                )
            }
            model_mat = alg.matrix4_scale_f32({0.5, 0.5, 0.5}) * model_mat
            model_mat = alg.matrix4_translate_f32(light_pos) * model_mat
            glw.shader_uniform_set("model",      &model_mat)


            gl.BindVertexArray(light_vao)
            draw_cube()

            // gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)


            imgui.Render()
            imgui_gl.RenderDrawData(imgui.GetDrawData())
            glfw.SwapBuffers(window_handle)
        }

        if seconds_accumulator >= 1 {
            when PRINT_FPS
            {
                fmt.printfln("FPS: %v", frame_count)
                fmt.printfln("IPS: %v", iteration_count)
            }

            imgui_io.Framerate  = f32(frame_count)
            seconds_accumulator = 0
            frame_count         = 0
            iteration_count     = 0
        }
    }

    fmt.printfln("Saving imgui_data... err: %v", save_imgui_data(imgui_data_filename, imgui_data))
}
