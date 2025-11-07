package learn_opengl

import "vendor:glfw"

global := struct
{
    camera:        Camera,
    mouse:         Mouse,
    viewport_size: Dimensions,
    dt:            f64,

    first_mouse_callback:  bool,
    key_pressed:           [glfw.KEY_LAST + 1]Key_State,
}{
    viewport_size = WINDOW_DEFAULT_SIZE,
    first_mouse_callback    = true
}

