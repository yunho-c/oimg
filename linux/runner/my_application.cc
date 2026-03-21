#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlView* view;
  FlMethodChannel* file_open_channel;
  bool file_open_channel_ready;
  GPtrArray* pending_open_requests;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {

constexpr char kFileOpenChannelName[] = "oimg/file_open";

char** paths_from_files(GFile** files, gint n_files) {
  GPtrArray* paths = g_ptr_array_new_with_free_func(g_free);
  for (gint i = 0; i < n_files; ++i) {
    char* path = g_file_get_path(files[i]);
    if (path != nullptr) {
      g_ptr_array_add(paths, path);
    }
  }
  g_ptr_array_add(paths, nullptr);
  return reinterpret_cast<char**>(g_ptr_array_free(paths, FALSE));
}

FlValue* paths_to_fl_value(char** paths) {
  FlValue* list = fl_value_new_list();
  if (paths == nullptr) {
    return list;
  }

  for (size_t i = 0; paths[i] != nullptr; ++i) {
    fl_value_append_take(list, fl_value_new_string(paths[i]));
  }

  return list;
}

void send_open_files(MyApplication* self, char** paths) {
  if (self->file_open_channel == nullptr || paths == nullptr) {
    return;
  }

  fl_method_channel_invoke_method(self->file_open_channel, "openFiles",
                                  paths_to_fl_value(paths), nullptr, nullptr,
                                  nullptr);
}

void flush_pending_open_requests(MyApplication* self) {
  if (!self->file_open_channel_ready) {
    return;
  }

  for (guint i = 0; i < self->pending_open_requests->len; ++i) {
    send_open_files(
        self,
        reinterpret_cast<char**>(g_ptr_array_index(self->pending_open_requests, i)));
  }
  g_ptr_array_set_size(self->pending_open_requests, 0);
}

void queue_open_files(MyApplication* self, char** paths) {
  if (paths == nullptr) {
    return;
  }

  if (self->file_open_channel_ready) {
    send_open_files(self, paths);
    g_strfreev(paths);
    return;
  }

  g_ptr_array_add(self->pending_open_requests, paths);
}

// Called when the Dart side signals that it is ready to receive native events.
static void file_open_method_call_cb(FlMethodChannel* channel,
                                     FlMethodCall* method_call,
                                     gpointer user_data) {
  (void)channel;
  MyApplication* self = MY_APPLICATION(user_data);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(fl_method_call_get_name(method_call), "ready") == 0) {
    self->file_open_channel_ready = true;
    flush_pending_open_requests(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send method response: %s", error->message);
  }
}

void create_file_open_channel(MyApplication* self) {
  FlEngine* engine = fl_view_get_engine(self->view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  self->file_open_channel = fl_method_channel_new(
      messenger, kFileOpenChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->file_open_channel,
                                           file_open_method_call_cb, self,
                                           nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

void present_existing_window(MyApplication* self) {
  if (self->window != nullptr) {
    gtk_window_present(self->window);
  }
}

}  // namespace

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    present_existing_window(self);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "OIMG");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "OIMG");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  self->view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(self->view, &background_color);
  gtk_widget_show(GTK_WIDGET(self->view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(self->view));

  g_signal_connect_swapped(self->view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(self->view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(self->view));
  create_file_open_channel(self);
  gtk_widget_grab_focus(GTK_WIDGET(self->view));
}

// Implements GApplication::open.
static void my_application_open(GApplication* application,
                                GFile** files,
                                gint n_files,
                                const gchar* hint) {
  (void)hint;
  MyApplication* self = MY_APPLICATION(application);
  char** paths = paths_from_files(files, n_files);
  if (self->view == nullptr) {
    g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
    self->dart_entrypoint_arguments = paths;
    g_application_activate(application);
    return;
  }

  queue_open_files(self, paths);
  present_existing_window(self);
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  g_clear_object(&self->file_open_channel);
  g_clear_pointer(&self->pending_open_requests, g_ptr_array_unref);

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  self->window = nullptr;
  self->view = nullptr;

  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->pending_open_requests = g_ptr_array_new_with_free_func(
      reinterpret_cast<GDestroyNotify>(g_strfreev));
}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(
      my_application_get_type(), "application-id", APPLICATION_ID, "flags",
      G_APPLICATION_HANDLES_OPEN, nullptr));
}
