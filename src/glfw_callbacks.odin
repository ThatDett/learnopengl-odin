package learn_opengl

import     "core:math"
import alg "core:math/linalg"

import gl "vendor:OpenGL"
import    "vendor:glfw"

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
    if mode == .free {
        return
    }
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

    global.camera.direction = alg.normalize(global.camera.direction)
    previous_position   = position
}
