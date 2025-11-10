package gl_wrapper

import "core:fmt"
import "core:path/filepath"

import gl "vendor:OpenGL"

import "dependencies:assimp/assimp/include/assimp/assimp"

model_load :: proc(path: cstring, caller_location := #caller_location) -> (model: Model, ok: bool)
{
    assimp.aiMaterial
    if !assimp_is_dll_loaded {
        assimp_load_DLL() or_return
        assimp_is_dll_loaded = true
    }

    scene := assimp_ImportFile(path, assimp.aiPostProcessSteps.Triangulate | assimp.aiPostProcessSteps.FlipUVs)
    if scene == nil || bool(scene.mFlags & assimp.AI_SCENE_FLAGS_INCOMPLETE) || scene.mRootNode == nil {
        fmt.eprintln("Error loading model: ", assimp.GetErrorString())
        return
    }

    model.directory = filepath.dir(cast(string)path)

    node_process(&model, scene.mRootNode, scene);
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
