// Boost Software License - Version 1.0 - August 17th, 2003
// See licenses/LICENSE-TDLib.txt

#include "td_json_client.h"
#include <dlfcn.h>
#include <stddef.h>

// Weak default definitions that can be overridden by linking libtdjson or dynamically resolved
__attribute__((weak)) int td_create_client_id(void) {
    typedef int (*fn_t)(void);
    fn_t real_fn = (fn_t)dlsym(RTLD_DEFAULT, "td_create_client_id");
    if (real_fn && real_fn != td_create_client_id) {
        return real_fn();
    }
    return -1; // -1 indicates native library is not linked/loaded
}

__attribute__((weak)) void td_send(int client_id, const char *request) {
    typedef void (*fn_t)(int, const char *);
    fn_t real_fn = (fn_t)dlsym(RTLD_DEFAULT, "td_send");
    if (real_fn && real_fn != td_send) {
        real_fn(client_id, request);
    }
}

__attribute__((weak)) const char *td_receive(double timeout) {
    typedef const char *(*fn_t)(double);
    fn_t real_fn = (fn_t)dlsym(RTLD_DEFAULT, "td_receive");
    if (real_fn && real_fn != td_receive) {
        return real_fn(timeout);
    }
    return NULL;
}

__attribute__((weak)) const char *td_execute(const char *request) {
    typedef const char *(*fn_t)(const char *);
    fn_t real_fn = (fn_t)dlsym(RTLD_DEFAULT, "td_execute");
    if (real_fn && real_fn != td_execute) {
        return real_fn(request);
    }
    return NULL;
}

__attribute__((weak)) void td_set_log_message_callback(int max_verbosity_level, td_log_message_callback_ptr callback) {
    typedef void (*fn_t)(int, td_log_message_callback_ptr);
    fn_t real_fn = (fn_t)dlsym(RTLD_DEFAULT, "td_set_log_message_callback");
    if (real_fn && real_fn != td_set_log_message_callback) {
        real_fn(max_verbosity_level, callback);
    }
}
