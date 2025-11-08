package gl_wrapper

import stbi "vendor:stb/image"

import gl "vendor:OpenGL"

Texture_Index :: u32

Image :: struct
{
    data:               [^]u8,
    width, height:      i32,
    number_of_channels: i32,
}

Texture :: struct
{
    id:    Handle,
    index: Texture_Index,
}

load_image :: proc(filepath: cstring) -> (image: Image, ok: bool)
{
    image.data = stbi.load(filepath, &image.width, &image.height, &image.number_of_channels, 0)
    if image.data == nil {
        // fmt.eprintfln("Could not load %v", filepath)
        return {}, ok
    }

    ok = true
    return image, ok
}

create_texture :: proc(image: Image, texture_index: Texture_Index, setup := proc() {
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.MIRRORED_REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.MIRRORED_REPEAT);
    gl.GenerateMipmap(gl.TEXTURE_2D)
}) -> Texture
{
    texture: Texture = ---
    texture.index    = texture_index
    gl.GenTextures(1, &texture.id)

    gl.ActiveTexture(gl.TEXTURE0 + texture_index)
    gl.BindTexture(gl.TEXTURE_2D, texture.id)

    setup()

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, image.width, image.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image.data)
    return texture
}

