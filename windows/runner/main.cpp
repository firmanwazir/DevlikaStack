#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Pure GUI mode: no console attachment or popups

  // Single-instance guard using a named system-wide Windows mutex
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, L"DevlikaStack_SingleInstance_Mutex_Unique");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running!
    // Bring the existing window to foreground
    HWND existing_window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Devlika Stack - Portable Web Development Environment");
    if (!existing_window) {
      existing_window = ::FindWindowW(nullptr, L"Devlika Stack - Portable Web Development Environment");
    }
    if (existing_window) {
      ::ShowWindow(existing_window, SW_SHOW);
      ::ShowWindow(existing_window, SW_RESTORE);
      ::SetForegroundWindow(existing_window);
    }
    if (mutex) {
      ::CloseHandle(mutex);
    }
    return EXIT_SUCCESS;
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
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Devlika Stack - Portable Web Development Environment", origin, size)) {
    if (mutex) {
      ::CloseHandle(mutex);
    }
    return EXIT_FAILURE;
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (mutex) {
    ::CloseHandle(mutex);
  }
  return EXIT_SUCCESS;
}
