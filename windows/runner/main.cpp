#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1024, 768);
  if (!window.Create(L"Xirja POS", origin, size)) {
    return EXIT_FAILURE;
  }
  // Disable resizing the window.
  HWND hwnd = window.GetHandle();
  LONG style = GetWindowLong(hwnd, GWL_STYLE);
  style &= ~WS_SIZEBOX; // Remove the sizing border
  // style &= ~WS_MAXIMIZEBOX; // Disable maximize button
  SetWindowLong(hwnd, GWL_STYLE, style);

  window.SetQuitOnClose(true);
  
  // Fullscreen toggle function
  bool is_fullscreen = false;
  auto toggle_fullscreen = [&]() {
    if (is_fullscreen) {
      SetWindowLong(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
      SetWindowPos(hwnd, HWND_TOP, 100, 100, 1024, 768, SWP_FRAMECHANGED);
    } else {
      SetWindowLong(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
      SetWindowPos(hwnd, HWND_TOP, 0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), SWP_FRAMECHANGED);
    }
    is_fullscreen = !is_fullscreen;
  };


  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    //detect when user press f11
    if (msg.message == WM_KEYDOWN && msg.wParam == VK_F11) {
      toggle_fullscreen();
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
