package assimp

import "core:fmt"
import "core:dynlib"
import "core:c"

assimp_is_dll_loaded := false

@(private)
aiImportFile:     rawptr

// @(private)
// aiGetErrorString: rawptr

@(private)
ImportFileType     :: #type proc "c" (file: cstring, flags: c.uint) -> ^Scene

@(private)
GetErrorStringType :: #type proc "c" () -> cstring

ImportFile : ImportFileType : proc "c" (file: cstring, flags: c.uint) -> ^Scene
{
    return ImportFileType(aiImportFile)(file, flags)
}

// GetErrorString : GetErrorStringType : proc "c" () -> cstring
// {
//     return GetErrorStringType(aiGetErrorString)()
// }

load_DLL :: proc() -> (ok: bool)
{
    load:       bool
    assimp_dll: dynlib.Library

    assimp_dll, load = dynlib.load_library("dependencies/assimp/libassimp-6.dll")
    if !load {
        fmt.println("Couldn't load assimp.")
        return ok
    }
    
    symbol := "aiImportFile"
    aiImportFile, load = dynlib.symbol_address(assimp_dll, symbol)
    if !load {
        fmt.println("Couldn't load", symbol)
        return ok
    }

    // symbol = "aiGetErrorString"
    // aiGetErrorString, load = dynlib.symbol_address(assimp_dll, symbol)
    // if !load {
    //     fmt.println("Couldn't load", symbol)
    //     return ok
    // }

    assimp_is_dll_loaded = true
    ok            = true
    return ok
}

// Node :: struct
// {
//     mName:           String,
//     mTransformation: matrix[4, 4]f32,
//     mParent:         ^Node,
//     mNumChildren:    c.uint,
//     mChildren:       [^]^Node,
//     mNumMeshes:      c.uint,
//     mMeshes:         [^]c.uint,
//     mMetaData:       ^Metadata,
// }

// TextureType :: 

// PropertyTypeInfo :: enum c.uint
// {
//     Float   = 0x1,
//     String  = 0x3,
//     Integer = 0x4,
//     Buffer  = 0x5,
// }

// MaterialProperty :: struct
// {
//     mKey:        String,
//     mSemantic:   c.uint,
//     mIndex:      c.uint,
//     mDataLength: c.uint,
//     mType:       PropertyTypeInfo,
//     mData:       rawptr,
// }

Material :: struct
{
    mProperties:    [^]^MaterialProperty,
    mNumProperties: c.uint,
    mNumAllocated:  c.uint,
}

Animation :: struct
{

}

Texture :: struct
{

}

Light :: struct
{

}

Camera :: struct
{

}

Metadata :: struct
{

}

String :: struct
{
    length: u32,
    data:   [MAXLEN]u8,
}

Skeleton :: struct
{

}

Scene :: struct
{
    mFlags:         c.uint,
    mRootNode:      ^Node,
    mNumMeshes:     c.uint,
    mMeshes:        [^]^Mesh,
    mNumMaterials:  c.uint,
    mMaterials:     [^]^Material,
    mNumAnimations: c.uint,
    mAnimations:    ^^Animation,
    mNumTextures:   c.uint,
    mTextures:      ^^Texture,
    mNumLights:     c.uint,
    mLights:        ^^Light,
    mNumCameras:    c.uint,
    mCameras:       ^^Camera,
    mMetadata:      ^Metadata,
    mName:          String,
    mNumSkeletons:  c.uint,
    mSkeletons:     ^^Skeleton,
}

