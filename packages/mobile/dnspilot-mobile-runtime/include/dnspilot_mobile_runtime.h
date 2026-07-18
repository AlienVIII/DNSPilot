#ifndef DNSPILOT_MOBILE_RUNTIME_H
#define DNSPILOT_MOBILE_RUNTIME_H

#ifdef __cplusplus
extern "C" {
#endif

char *dnspilot_run_action(const char *action, const char *payload_json, const char *db_path);
void dnspilot_free_string(char *value);

#ifdef __cplusplus
}
#endif

#endif
