extends GutTest
## The Android update check's rules: which version is newer, and what a version.json has to say.

const URL := "https://example.com/play/version.json"


func test_versions_compare_by_number_not_by_text() -> void:
	assert_true(UpdateChecker.is_newer("0.0.2", "0.0.1"))
	assert_true(UpdateChecker.is_newer("0.10.0", "0.9.9"), "10 is more than 9")
	assert_true(UpdateChecker.is_newer("1.0", "0.9.9"))
	assert_false(UpdateChecker.is_newer("0.0.1", "0.0.1"), "the same version")
	assert_false(UpdateChecker.is_newer("0.0.1", "0.0.2"), "an older one")
	assert_false(UpdateChecker.is_newer("1.0", "1.0.0"), "missing parts count as zero")


func test_nonsense_versions_are_never_newer() -> void:
	assert_false(UpdateChecker.is_newer("", "0.0.1"))
	assert_false(UpdateChecker.is_newer("soon", "0.0.1"))
	assert_false(UpdateChecker.is_newer("0.0.2", "unknown"))
	assert_eq(UpdateChecker.parse_version("v1.2.3"), [1, 2, 3] as Array[int])


func test_a_newer_release_gets_an_absolute_apk_address() -> void:
	var body := '{"version": "0.0.2", "apk": "hollow-creek.apk", "notes": "Phone layout fixes."}'
	var found := UpdateChecker.newer_release(body, "0.0.1", URL)
	assert_eq(found["version"], "0.0.2")
	assert_eq(found["apk"], "https://example.com/play/hollow-creek.apk")
	assert_eq(found["notes"], "Phone layout fixes.")


func test_an_absolute_apk_address_is_kept() -> void:
	var body := '{"version": "0.0.2", "apk": "https://cdn.example.com/hc.apk"}'
	assert_eq(UpdateChecker.newer_release(body, "0.0.1", URL)["apk"], "https://cdn.example.com/hc.apk")


func test_nothing_to_offer_when_not_newer_or_unreadable() -> void:
	assert_true(UpdateChecker.newer_release('{"version": "0.0.1", "apk": "a.apk"}', "0.0.1", URL).is_empty(), "same version")
	assert_true(UpdateChecker.newer_release('{"version": "0.0.2"}', "0.0.1", URL).is_empty(), "no apk named")
	assert_true(UpdateChecker.newer_release("not json", "0.0.1", URL).is_empty())
	assert_true(UpdateChecker.newer_release('[1, 2]', "0.0.1", URL).is_empty())
	assert_true(UpdateChecker.newer_release('{"version": "0.0.2", "apk": "a.apk"}', "0.0.1", "http://insecure.example.com/version.json").is_empty(), "plain http is refused")
