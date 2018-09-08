import gltf2opengl, gltf2;
import std.stdio;
import std.file : read;
import glviewer;
import std.algorithm, std.range;
import gl3n.math, gl3n.linalg;
import vector;
import derelict.glfw3, derelict.opengl;
import std.datetime.stopwatch;

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

  private immutable static float3 up = float3(0.0f, -1.0f, 0.0f);
  float4x4 View_Matrix(float time) {
    float3 bbox_len = float3(
      max(bbox_max.x, abs(bbox_min.x)),
      max(bbox_max.y, abs(bbox_min.y)),
      max(bbox_max.z, abs(bbox_min.z)),
    );
    float3 O, center = float3(0.0f);
    float X = max(max(bbox_len.x, bbox_len.z), bbox_len.y)*1.1f;
    O = float3(X, X, X);

    auto mouse_offset = Mouse_Position();
    mouse_offset[0] *= 6.21f;
    mouse_offset[1] *= 6.21f;
    O.x *= sin(mouse_offset[0]) * sin(mouse_offset[1])*2.0f;
    O.z *= cos(mouse_offset[0]) * sin(mouse_offset[1])*2.0f;
    O.y *= cos(mouse_offset[1]);
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

// TODO it's from glshader
GLuint Load_Shaders(string vertex, string fragment) {
  import std.stdio, std.string;
  GLuint vshader = glCreateShader(GL_VERTEX_SHADER),
         fshader = glCreateShader(GL_FRAGMENT_SHADER);

  void Check ( string nam, GLuint sh ) {
    GLint res;
    int info_log_length;
    glGetShaderiv(sh, GL_COMPILE_STATUS, &res);
    glGetShaderiv(sh, GL_INFO_LOG_LENGTH, &info_log_length);
    if ( info_log_length > 0 ){
      char[] msg; msg.length = info_log_length+1;
      glGetShaderInfoLog(sh, info_log_length, null, msg.ptr);
      writeln(nam, ": ", msg);
      assert(false);
    }
  }

  immutable(char)* vertex_c   = toStringz(vertex),
                   fragment_c = toStringz(fragment);
  glShaderSource(vshader, 1, &vertex_c, null);
  glCompileShader(vshader);
  Check("vertex", vshader);

  glShaderSource(fshader, 1, &fragment_c, null);
  glCompileShader(fshader);
  Check("fragment", fshader);

  GLuint program_id = glCreateProgram();
  glAttachShader(program_id, vshader);
  glAttachShader(program_id, fshader);
  glLinkProgram(program_id);
  glDetachShader(program_id, vshader);
  glDetachShader(program_id, fshader);
  glDeleteShader(vshader);
  glDeleteShader(fshader);
  return program_id;
}


float4x4 View_Proj ( float4x4 transform ) {
  float3 O = float3(-3.0f, 3.0f, -3f), C = float3(0.0f);
  O = (transform*float4(O, 0.0f)).xyz;
  return float4x4.look_at(O, C, float3(0.0f, 1.0f, 0.0f));
}
// float4x4 View_Proj ( float4x4 transform ) {
//   float3 O = float3(-3.0f, 3.0f, -3f), C = float3(0.0f);
//   O = (transform*float4(O, 0.0f)).xyz;
//   return float4x4.look_at(O, C, float3(0.0f, 1.0f, 0.0f));
// }

struct BlahRender {
  GLuint render_vao, render_program, render_mode;
  GLuint position_buffer;

  float[] vertices = [
      -1.0f, 1.0f,
      1.0f, 1.0f,
      1.0f, -1.0f,

      -1.0f, 1.0f,
      1.0f, -1.0f,
      -1.0f, -1.0f,
   ];

  void Allocate ( ) {
    glGenVertexArrays(1, &render_vao);
    glBindVertexArray(render_vao);
    glGenBuffers(1, &position_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, position_buffer);
    glBufferData(GL_ARRAY_BUFFER, vertices.length * vertices[0].sizeof, vertices.ptr, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, position_buffer);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, cast(void*)0);

    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    render_program = Load_Shaders(
    q{#version 450 core
      in layout(location = 0) vec2 Position;
      out layout(location = 0) vec3 fragPosition;
      out layout(location = 1) vec3 fragWi;

      void main ( ) {
        gl_Position = vec4(Position, 0.9f, 1.0f);
        fragPosition = gl_Position.xyz;
        fragWi = -normalize(gl_Position.xyz);
      }
    },
    q{#version 450 core
      out layout(location = 0) vec4 outColor;
      in layout(location = 0) vec3 fragPosition;
      in layout(location = 0) vec3 fragWi;
      void main ( ) {
        outColor = vec4(fragPosition, 1.0f);
      }
    });
  }

  void Render() {
    glUseProgram(render_program);
    glBindVertexArray(render_vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
  }
}

void main() {
  Initialize_GL();

  /*
    specifications:
      #-Y feature works
      #-N feature does not work
      #-Q feature not applicable

      V => model can be viewed (it matches sample image disregarding lighting)
            (when Q is here, it means that the model is disfigured)
      A => animations work
      C => camera works (default camera, mouse camera, and glTF cameras)
      G => lighting works

      XXX => model CRASHES on load
  */

  // auto obj = Test_glTF("TriangleWithoutIndices");   // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("Triangle");                 // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("AnimatedTriangle");         // 08/11/18 V-Y A-N C-N G-N
  // auto obj = Test_glTF("AnimatedMorphCube");        // 08/11/18 XXX
  // auto obj = Test_glTF("AnimatedMorphSphere");      // 08/11/18 XXX
  // auto obj = Test_glTF("SimpleMeshes");             // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("SimpleMorph");              // 08/11/18 XXX
  // auto obj = Test_glTF("SimpleSparseAccessor");     // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("Cameras");                  // 08/11/18 V-Y A-Q C-N G-N
  auto obj = Test_glTF("Box");                      // 08/11/18 V-N A-Q C-N G-N
  // auto obj = Test_glTF("BoxInterleaved");           // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("BoxTextured");              // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("BoxTexturedNonPowerOfTwo"); // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("BoxVertexColors");          // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("Duck");                     // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("2CylinderEngine");          // 08/11/18 V-N
  // auto obj = Test_glTF("ReciprocatingSaw");         // 08/11/18 V-N
  // auto obj = Test_glTF("GearboxAssy");         // 08/11/18 V-N
  // auto obj = Test_glTF("Buggy");         // 08/11/18 V-N
  // auto obj = Test_glTF("BoxAnimated");         // 08/11/18 XXX
  // auto obj = Test_glTF("CesiumMilkTruck");         // 08/11/18 XXX
  // auto obj = Test_glTF("RiggedSimple");         // 08/11/18 XXX
  // auto obj = Test_glTF("RiggedFigure");         // 08/11/18 XXX
  // auto obj = Test_glTF("CesiumMan");         // 08/11/18 XXX
  // auto obj = Test_glTF("Monster");         // 08/11/18 XXX
  // auto obj = Test_glTF("BrainStem");         // 08/11/18 XXX
  // auto obj = Test_glTF("VirtualCity");         // 08/11/18 XXX
  // auto obj = Test_glTF("Avocado");         // 08/11/18 V-N
  // auto obj = Test_glTF("BarramundiFish");         // 08/11/18 V-N
  // auto obj = Test_glTF("BoomBox");         // 08/11/18 V-N
  // auto obj = Test_glTF("Corset");         // 08/11/18 V-N
  // auto obj = Test_glTF("DamagedHelmet");         // 08/11/18 XXX
  // auto obj = Test_glTF("FlightHelmet");         // 08/11/18 V-N
  // auto obj = Test_glTF("Lantern");         // 08/11/18 V-N
  // auto obj = Test_glTF("WaterBottle");         // 08/11/18 V-N
  // auto obj = Test_glTF("TwoSidedPlane");         // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("Cube");         // 08/11/18 XXX
  // auto obj = Test_glTF("AnimatedCube");         // 08/11/18 XXX
  // auto obj = Test_glTF("Suzanne");         // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("SciFiHelmet");         // 08/11/18 V-Y A-Q C-N G-N
  // auto obj = Test_glTF("BoomBoxWithAxes");         // 08/11/18 V-N
  // auto obj = Test_glTF("MetalRoughSpheres");         // 08/11/18 V-Q

  // --- IMPORTANT TESTS ---
  // auto obj = Test_glTF("AlphaBlendModeTest");         // 08/11/18 V-Y test failed
  // auto obj = Test_glTF("NormalTangentTest");         // 08/11/18 V-Y test failed
  // auto obj = Test_glTF("NormalTangentMirrorTest");         // 08/11/18 V-Y test failed
  // auto obj = Test_glTF("OrientationTest");         // 08/11/18 V-Y test failed
  // auto obj = Test_glTF("TextureCoordinateTest");         // 08/11/18 V-Y test passed
  // auto obj = Test_glTF("TextureSettingsTest");         // 08/11/18 V-Y test failed
  // auto obj = Test_glTF("VertexColorTest");         // 08/11/18 V-Y test passed
  // auto obj = Test_glTF("TextureTransformTest");         // 08/11/18 XXX

  auto default_scene = obj.RDefault_Scene();
  auto camera_node = default_scene.RCamera_Node();

  // BlahRender quad_render;
  // quad_render.Allocate();
  Camera rotating_camera = Camera(obj);

  float time, ptime = 0.0f;
  writeln("RENDER ", obj.meshes.length, " MESH(ES)");

  do {
		float start = glfwGetTime();
    time = Update_Start()*0.1f;
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

    // render quad
    // quad_render.Render();

    // render scene
    foreach ( node; default_scene.gltf.nodes ) {
      obj.nodes[node].gl.Render(obj, view_mtx, projection_mtx, model_mtx);
    }
		glfwSwapBuffers(window);
		glfwPollEvents();
		float end = glfwGetTime();
    ptime = time;
  } while ( Update_End );
}
