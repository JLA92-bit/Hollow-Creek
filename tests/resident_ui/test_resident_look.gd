extends GutTest
## Residents' looks come from their data (appearance line, model), and the card describes what
## they're doing in plain words.


func test_looks_from_data() -> void:
	var data: Dictionary = Sim.load_data()["residents"]
	var agnes := ResidentLook.for_resident("r_agnes", data["r_agnes"])
	assert_eq(agnes["model"], "agnes", "Agnes has her own MPFB model")
	assert_eq(agnes["hair"], ResidentLook.HAIR["grey"])
	assert_eq(agnes["top"], ResidentLook.TOPS["cardigan"])
	assert_true(agnes.has("legs"), "the MPFB models have a legs slot")
	var len := ResidentLook.for_resident("r_len", data["r_len"])
	assert_eq(len["model"], "mannequin_m")
	assert_eq(ResidentLook.for_resident("r_len", data["r_len"]), len, "the same look every time")


func test_doing_in_words() -> void:
	var t := SimTown.build(MapSlice.load_default().grid, DemoTown.houses(), [], [])
	var s := Sim.new(3)
	s.setup(t, Sim.load_data(), DemoTown.homes(), 1, 10 * 60)
	var r: Dictionary = s.residents["r_len"]
	r["action"] = {"kind": "work", "place": "lm_mill"}
	r["route"] = []
	assert_eq(ResidentPanel.doing(s, r), "Working at the mill")
	r["route"] = [[0, 1.0, 1.0], [0, 2.0, 1.0]]
	assert_eq(ResidentPanel.doing(s, r), "Off to work at the mill")
	r["action"] = {"kind": "visit", "place": "visit:r_tomasz"}
	assert_eq(ResidentPanel.doing(s, r), "Walking over to see Tomasz")
	r["route"] = []
	r["action"] = {"kind": "sleep", "place": "x"}
	assert_eq(ResidentPanel.doing(s, r), "Asleep")
