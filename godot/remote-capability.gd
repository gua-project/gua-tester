extends RefCounted

static func check(info: Variant) -> String:
    if not info is Dictionary or typeof(info.get("remoteEnabled")) != TYPE_BOOL:
        return "Invalid native build-info; replace the complete matching addon."
    if not info.remoteEnabled:
        return "This addon has no remote implementation (ordinary release / shipping). Environment variables and Player profile cannot enable it. Select a remote-enabled addon built with GUA_ENABLE_REMOTE_AUTOMATION=ON."
    var flavor = info.get("flavor", "")
    var ceiling = info.get("remotePermissionCeiling", "")
    if flavor not in ["development", "qa", "ai-player"]:
        return "Unknown remote build purpose."
    if ceiling != ("player" if flavor == "ai-player" else "debug"):
        return "Native permission ceiling does not match the build purpose; Player cannot be elevated to Debug."
    if not info.get("transports") is Array or "websocket" not in info.transports:
        return "This addon has no desktop WebSocket transport."
    return ""
