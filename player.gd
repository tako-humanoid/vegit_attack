extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var mesh = $MeshInstance3D
var speed = 8.0

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	# UIが表示されないバグ対策：コードで同期項目を登録
	var sync = $MultiplayerSynchronizer
	var config = SceneReplicationConfig.new()
	config.add_property(".:global_position")
	sync.replication_config = config
	
	_setup_visuals()

	# 権限がない（他人の）キャラは物理計算をさせない
	if not is_multiplayer_authority():
		set_physics_process(false)

func _setup_visuals():
	var mat = StandardMaterial3D.new()
	var my_id = name.to_int()
	mat.albedo_color = Color.RED if my_id == 1 else Color.BLUE
	mesh.material_override = mat

func set_target_position(target: Vector3):
	nav_agent.target_position = target

func _physics_process(_delta):
	if nav_agent.is_navigation_finished(): return
	var next_pos = nav_agent.get_next_path_position()
	velocity = (next_pos - global_position).normalized() * speed
	move_and_slide()
