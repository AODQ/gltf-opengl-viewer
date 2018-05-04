module glviewer;
import derelict.opengl, derelict.glfw3;
import vector;

GLFWwindow* window;
int window_width = 640, window_height = 480;

void Initialize_GL ( ) {
  DerelictGL3.load();
  DerelictGLFW3.load();
  glfwInit();

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE );
  glfwWindowHint(GLFW_RESIZABLE,      GL_FALSE                 );
  glfwWindowHint(GLFW_FLOATING,       GL_TRUE                  );
  glfwWindowHint(GLFW_REFRESH_RATE,  0                         );
  glfwSwapInterval(1);

  window = glfwCreateWindow(window_width, window_height, "glTF2 viewer",
                            null, null);

  glfwWindowHint(GLFW_FLOATING, GL_TRUE);
  glfwMakeContextCurrent(window);
  DerelictGL3.reload();
  glClampColor(GL_CLAMP_READ_COLOR, GL_FALSE);
  glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS_ARB);

  glClearColor(0.02f, 0.02f, 0.02f, 1.0f);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LESS);
  // glDisable(GL_DEPTH_TEST);

  glEnable(GL_DEBUG_OUTPUT);
  glDebugMessageCallback(cast(GLDEBUGPROC)&Message_Callback, null);
}

extern(C) void Message_Callback(
              GLenum source, GLenum type, GLuint id, GLenum severity,
              GLsizei length, const GLchar* message, const void* userParam ) {
  import core.stdc.stdio;
  printf( "GL CALLBACK: type = 0x%x, severity = 0x%x, message %s\n",
            type, severity, message );
}

float Update_Start ( ) {
  static float time = 0.0f;
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  float frame_time = glfwGetTime();
  float delta = (frame_time - time);
  time = frame_time;
  return time;
}
bool Update_End() {
  glfwSwapBuffers(window);
  glfwPollEvents();
  return !(glfwWindowShouldClose(window) ||
            glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS ||
            glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS);
}

bool Mouse_Left ( ) {
  return glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS;
}

float[2] Mouse_Position ( ) {
  if ( glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_RELEASE )
    return [0f, 0f];
  double d_xpos, d_ypos;
  glfwGetCursorPos(window, &d_xpos, &d_ypos);
  return cast(float[2])[d_xpos/cast(float)window_width,
                        d_ypos/cast(float)window_height];
}

float[2] Mouse_Offset ( ) {
  static float last_xpos = 0f, last_ypos = 0f;
  double d_xpos, d_ypos;
  glfwGetCursorPos(window, &d_xpos, &d_ypos);
  float xpos = d_xpos, ypos = d_ypos;

  float[2] ret = [0f, 0f];
  if ( glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS )
    ret = [xpos - last_xpos, ypos - last_ypos];
  last_xpos = xpos; last_ypos = ypos;
  return ret;
}
