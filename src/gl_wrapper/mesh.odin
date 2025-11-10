package gl_wrapper

import "core:strings"
import "core:strconv"

import gl "vendor:OpenGL"

import "dependencies:assimp"

Vector3D :: [3]f32
Vector2D :: [2]f32

Vertex :: struct
{
    position:      Vector3D,
    normal:        Vector3D,
    texture_coord: Vector2D,
}

Mesh :: struct
{
    vertices: [dynamic]Vertex,
    indices:  [dynamic]u32,
    textures: [dynamic]Texture,

    vao, vbo, ebo: Handle,
}

@(private)
mesh_init :: proc(mesh: ^Mesh)
{
    gl.GenVertexArrays(1, &mesh.vao)
    gl.GenBuffers(1, &mesh.vbo)
    gl.GenBuffers(1, &mesh.ebo)

    gl.BindVertexArray(mesh.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)

    gl.BufferData(gl.ARRAY_BUFFER, len(mesh.vertices) * size_of(Vertex), raw_data(mesh.vertices), gl.STATIC_DRAW)  

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(mesh.indices) * size_of(u32), raw_data(mesh.indices), gl.STATIC_DRAW)

    // vertex positions
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, size_of(Vector3D), gl.FLOAT, gl.FALSE, size_of(Vertex), 0)

    // vertex normals
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, size_of(Vector3D), gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of_by_string(Vertex, "normal"))

    // vertex texture coords
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, size_of(Vector2D), gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of_by_string(Vertex, "texture_coord"))

    gl.BindVertexArray(0)
}

mesh_draw :: proc(mesh: Mesh, shader: Shader)
{
    PREFIX :: "material."
    diffuse_number, specular_number: u8

    shader_use(shader)
    for texture, i in mesh.textures {
        gl.ActiveTexture(gl.TEXTURE0)

        number: u8
        name := texture.type
        if strings.compare(name, "texture_diffuse") == 0 {
            number          = diffuse_number
            diffuse_number += 1
        }
        else if strings.compare(name, "texture_specular") == 0 {
            number           = specular_number
            specular_number += 1
        }
        else {
            panic("Unreachable")
        }

        buffer: [4]byte
        number_to_string := strconv.write_uint(buffer[:], cast(u64)number, 10)

        fullname_buffer := make([]byte, len(PREFIX) + len(name) + len(number_to_string) + 1)
        defer delete(fullname_buffer)

        f_i := 0
        for c in PREFIX {
            fullname_buffer[f_i] = cast(byte)c
            f_i += 1
        }
        for c in name {
            fullname_buffer[f_i] = cast(byte)c
            f_i += 1
        }
        for c in number_to_string {
            fullname_buffer[f_i] = cast(byte)c
            f_i += 1
        }

        fullname_buffer[i] = 0

        shader_uniform_set_int(cast(cstring)raw_data(fullname_buffer), cast(i32)i)
        gl.BindTexture(gl.TEXTURE_2D, texture.id)
    }

    shader_use({})

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindVertexArray(mesh.vao)
    gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)
    gl.BindVertexArray(0)
}

@(private)
mesh_process :: proc(mesh: ^assimp.Mesh, scene: ^assimp.Scene) -> (out_mesh: Mesh)
{
    out_mesh.vertices = make_dynamic_array_len_cap([dynamic]Vertex, 0, 256)
    out_mesh.indices  = make_dynamic_array_len_cap([dynamic]u32, 0, 256)
    out_mesh.textures = make_dynamic_array_len_cap([dynamic]Texture, 0, 256)
    for i in 0..<mesh.mNumVertices {
        vertex: Vertex
        vertex.position = mesh.mVertices[i]
        vertex.normal   = mesh.mNormals[i]

        if mesh.mTextureCoords[0] != nil {
            vertex.texture_coord = mesh.mTextureCoords[0][i].xy
        }
        append(&out_mesh.vertices, vertex)
    }

    for i in 0..<mesh.mNumFaces {
        face := mesh.mFaces[i]
        for j in 0..<face.mNumIndices {
            append(&out_mesh.indices, face.mIndices[j])
        }
    }

    if mesh.mMaterialIndex >= 0 {
        material := scene.mMaterials[mesh.mMaterialIndex]
        diffuse_maps  := load_material_textures(material, assimp.TextureType.DIFFUSE,  "texture_diffuse")
        specular_maps := load_material_textures(material, assimp.TextureType.SPECULAR, "texture_specular")
        defer {
            delete(diffuse_maps)
            delete(specular_maps)
        }

        for diffuse_map in diffuse_maps {
            append(&out_mesh.textures, diffuse_map)
        }

        for specular_map in specular_maps {
            append(&out_mesh.textures, specular_map)
        }
    }
    return out_mesh
}

load_material_textures :: proc(material: ^assimp.Material, texture_type: assimp.TextureType, name: string) -> [dynamic]Texture
{
    return {}
}

mesh_delete :: proc(mesh: ^Mesh)
{
    delete(mesh.vertices)
    delete(mesh.indices)
    delete(mesh.textures)
}
