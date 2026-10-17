class_name UrlParams
extends RefCounted
## Reads ?key=value options from the page URL on the web, or "-- key=value" user args on desktop.


static func read() -> Dictionary:
	var out := {}
	var query := ""
	if OS.has_feature("web"):
		query = str(JavaScriptBridge.eval("window.location.search || ''"))
		query = query.trim_prefix("?")
		for part in query.split("&", false):
			var kv := part.split("=", true, 1)
			out[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else "1"
	for arg in OS.get_cmdline_user_args():
		var kv2 := arg.trim_prefix("--").split("=", true, 1)
		out[kv2[0]] = kv2[1] if kv2.size() > 1 else "1"
	return out
