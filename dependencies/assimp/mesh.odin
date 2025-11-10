package assimp

import "core:c"

MAX_NUMBER_OF_COLOR_SETS    :: 8
MAX_NUMBER_OF_TEXTURECOORDS :: 8

Vector3D :: [3]f32
Color4D  :: [4]f32

Face :: struct
{
    mNumIndices: c.uint,
    mIndices:    [^]c.uint,
}

Bone :: struct
{

}

AnimMesh :: struct
{

}

MorphingMethod :: enum
{
    UNKNOWN,
    VEXTEX_BLEND,
    MORPH_NORMALIZED,
    MORPH_RELATIVE,
}

AABB :: struct
{
    mMin: Vector3D,
    mMax: Vector3D,
}

Mesh :: struct
{
    mPrimitiveTypes:     c.uint,
    mNumVertices:        c.uint,
    mNumFaces:           c.uint,
    mVertices:           [^]Vector3D,
    mNormals:            [^]Vector3D,
    mTangents:           [^]Vector3D,
    mBitangents:         [^]Vector3D,
    mColors:             [MAX_NUMBER_OF_COLOR_SETS][^]Color4D,
    mTextureCoords:      [MAX_NUMBER_OF_TEXTURECOORDS][^]Vector3D,
    mNumUVComponents:    [MAX_NUMBER_OF_TEXTURECOORDS]c.uint,
    mFaces:              [^]Face,
    mNumBones:           c.uint,
    mBones:              [^]^Bone,
    mMaterialIndex:      c.uint,
    mName:               String,
    mNumAnimMeshes:      c.uint,
    mAnimeMeshes:        [^]^AnimMesh,
    mMethod:             MorphingMethod,
    mAABB:               AABB,
    mTextureCoordsNames: [^]^String
}
