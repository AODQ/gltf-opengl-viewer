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

  this ( GL_glTFRoot obj ) {
    // find bbox max/min by iterating over every mesh
    // TODO : iterate nodes and uses matrices
    bbox_max = float3(-float.max);
    bbox_min = float3( float.max);
    foreach ( ref mesh; obj.meshes ) {
      foreach ( ref primitive; mesh.gltf.primitives ) {
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
  float4x4 View_Matrix(float time) {
    float3 bbox_len = float3(
      max(bbox_max.x, abs(bbox_min.x)),
      max(bbox_max.y, abs(bbox_min.y)),
      max(bbox_max.z, abs(bbox_min.z)),
    );
    float3 O, center = float3(0.0f);
    float X = max(bbox_len.x, bbox_len.z);
    O = float3(X, 0.0f, X)*2.5f;
    auto mouse_offset = Mouse_Position();
    mouse_offset[0] *= 6.21f;
    O.x *= sin(mouse_offset[0]);
    O.z *= cos(mouse_offset[0]);
    return float4x4.look_at(O, center, up);
  }
  float4x4 Projection_Matrix(float time) {
    return float4x4.perspective(640.0f, 480.0f, 90.0f, 0.1f, 9999.0f);
  }
}

auto Test_glTF ( string file ) {
  import std.string : format;
  file = "glTF-Sample-Models/2.0/%s/glTF/%s.gltf".format(file, file);
  return new GL_glTFRoot(file);
}

auto Test_glTFBinary ( string file ) {
}

auto Test_Embedded ( string file ) {
}

auto Test_glTFpbrSpecularGlossiness ( string file ) {
}


float4x4 View_Proj ( float4x4 transform ) {
  float3 O = float3(-3.0f, 3.0f, -3f), C = float3(0.0f);
  O = (transform*float4(O, 0.0f)).xyz;
  return float4x4.look_at(O, C, float3(0.0f, 1.0f, 0.0f));
}

void main() {
  Initialize_GL();

  // auto obj = Test_glTF("TriangleWithoutIndices");
  // auto obj = Test_glTF("Triangle");
  auto obj = Test_glTF("AnimatedTriangle");
  // auto obj = Test_glTF("Box");
  // auto obj = Test_glTF("BoxInterleaved");
  // auto obj = Test_glTF("BoxTextured");
  // auto obj = Test_glTF("BoxTexturedNonPowerOfTwo");
  // auto obj = Test_glTF("BoxVertexColors");
  // auto obj = Test_glTF("Duck");
  // auto obj = Test_glTF("2CylinderEngine");
  // auto obj = Test_glTF("Avocado");
  // auto obj = Test_glTF("Cube");
  // auto obj = Test_glTF("SciFiHelmet");
  // auto obj = Test_glTF("Suzanne");
  // auto obj = Test_glTF("WaterBottle");
  // auto obj = Test_glTF("MetalRoughSpheres");
  // auto obj = Test_glTF("OrientationTest");
  // auto obj = Test_glTF("RiggedSimple");
  // auto obj = Test_glTF("BrainStem");
  // auto obj = Test_glTF("VC");
  // auto obj = Test_glTF("DamagedHelmet");
  // auto obj = Test_glTF("CesiumMan");
  // auto camera = Camera(obj);

  auto default_scene = obj.RDefault_Scene();
  auto camera_node = default_scene.RCamera_Node();

  Camera rotating_camera = Camera(obj);

  float time, ptime = 0.0f;
  writeln("RENDER ", obj.meshes.length, " MESH(ES)");
  do {
    time = Update_Start();
    obj.Update_Animation(time);
    float4x4 view_mtx, projection_mtx, model_mtx = float4x4.identity;
    if ( camera_node !is null && !Mouse_Left ) {
      auto camera = camera_node.RCamera;
      view_mtx = View_Proj(camera_node.RModel_Matrix);
      projection_mtx = camera.gl.projection_matrix;
    } else {
      view_mtx = rotating_camera.View_Matrix(time);
      projection_mtx = rotating_camera.Projection_Matrix(time);
    }
    foreach ( node; default_scene.gltf.nodes ) {
      obj.nodes[node].gl.Render(obj, view_mtx, projection_mtx, model_mtx);
    }
    ptime = time;
  } while ( Update_End );
}
