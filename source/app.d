import gltf2opengl, gltf2;
import std.stdio;
import std.file : read;
import glviewer;
import std.algorithm, std.range;
import gl3n.math, gl3n.linalg;
import vector;
import derelict.glfw3, derelict.opengl;

struct Camera {
  float3 bbox_max, bbox_min;

  this ( glTFObject obj ) {
    // find bbox max/min by iterating over every mesh
    bbox_max = float3(-float.max);
    bbox_min = float3( float.max);
    foreach ( ref mesh; obj.meshes ) {
      foreach ( ref primitive; mesh.primitives ) {
        auto accessor = primitive.RAccessor(glTFAttribute.Position);
        float T = cast(float)accessor.max[0].get!real;
        bbox_max.x = max(accessor.max[0].get!real, bbox_max.x);
        bbox_max.y = max(accessor.max[1].get!real, bbox_max.y);
        bbox_max.z = max(accessor.max[2].get!real, bbox_max.z);
        bbox_min.x = min(accessor.min[0].get!real, bbox_min.x);
        bbox_min.y = min(accessor.min[1].get!real, bbox_min.y);
        bbox_min.z = min(accessor.min[2].get!real, bbox_min.z);
      }
    }
  }

  private immutable static float3 up = float3(0.0f, 1.0f, 0.0f);
  float4x4 Camera_Matrix (float time) {
    float3 bbox_len = abs(bbox_max-bbox_min);
    float3 O, center = float3(0.0f);
    O = float3(bbox_max.x, bbox_max.y, bbox_max.z)*2.0f;
    return
      float4x4.perspective(640.0f, 480.0f, 60.0f, 0.1f, 10.0f) *
      float4x4.look_at(O, center, up);
  }
}

auto Test_glTF ( string file ) {
  import std.string : format;
  file = "glTF-Sample-Models/2.0/%s/glTF/%s.gltf".format(file, file);
  writeln(file);
  return GL_glTF_Load_File(file);
}

auto Test_glTFBinary ( string file ) {
}

auto Test_Embedded ( string file ) {
}

auto Test_glTFpbrSpecularGlossiness ( string file ) {
}

void main() {
  Initialize_GL();

  // auto obj = Test_glTF("TriangleWithoutIndices");
  // auto obj = Test_glTF("Triangle");
  // auto obj = Test_glTF("Box");
  auto obj = Test_glTF("BoxTextured");
  // auto obj = Test_glTF("BoxInterleaved");
  // auto obj = Test_glTF("SciFiHelmet");
  // auto obj = Test_glTF("Suzanne");
  // auto obj = Test_glTF("WaterBottle");
  auto camera = Camera(obj.gltf);

  float time, ptime = 0.0f;
  do {
    time = Update_Start();
    auto mtx = camera.Camera_Matrix(time);
    mtx = mtx*float4x4.identity.rotate(time*1.0f, float3(0.4f, 0.0f, 1.3f));
    obj.meshes[0].Render(mtx);
    ptime = time;
  } while ( Update_End );
}
