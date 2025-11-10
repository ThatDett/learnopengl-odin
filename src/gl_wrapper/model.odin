package gl_wrapper

import "core:fmt"
import "core:path/filepath"

import gl "vendor:OpenGL"

import "dependencies:assimp"

Model :: struct
{
    meshes:    [dynamic]Mesh,
    directory: string
}

assimp_load :: #force_inline proc()
{
    assimp.Load_DLL()
}

model_load :: proc(path: cstring, caller_location := #caller_location) -> (model: Model, ok: bool)
{
    scene := assimp.ImportFile(path, u32(assimp.PostProcessSteps.Triangulate | assimp.PostProcessSteps.FlipUVs))
    if scene == nil || bool(scene.mFlags & cast(u32)assimp.SceneFlags.INCOMPLETE) || scene.mRootNode == nil {
        fmt.eprintln("Error loading model: ", assimp.GetErrorString())
        return
    }

    model.directory = filepath.dir(cast(string)path)

    // node_process(&model, scene.mRootNode, scene);
    return model, ok
}

model_draw :: proc(model: Model, shader: Shader)
{
    for mesh in model.meshes {
        mesh_draw(mesh, shader)
    }
}

@(private="file")
node_process :: proc(model: ^Model, node: ^assimp.Node, scene: ^assimp.Scene)
{
    for i in 0..<node.mNumMeshes {
        mesh := scene.mMeshes[node.mMeshes[i]]
        append(&model.meshes, mesh_process(mesh, scene))
    }

    for i in 0..<node.mNumChildren {
        node_process(model, node.mChildren[i], scene)
    }
}

model_delete :: proc(model: Model)
{
    for &mesh in model.meshes {
        mesh_delete(&mesh)
    }
    delete(model.directory)
}
