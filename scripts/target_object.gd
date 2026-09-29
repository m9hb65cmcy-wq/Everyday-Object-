class_name TargetObject
extends RigidBody3D

signal grabbed(target: TargetObject)

@export var object_id := ""
@export var display_name := ""
var _base_transform := Transform3D.IDENTITY
var _grab_owner: Node
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _detail_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
    _base_transform = global_transform
    gravity_scale = 0.0
    freeze = false
    for node in find_children("*", "MeshInstance3D", true, false):
        var visual := node as MeshInstance3D
        if visual.name.begins_with("Detail"):
            _detail_meshes.append(visual)
        for surface in visual.mesh.get_surface_count():
            var original := visual.get_active_material(surface) as StandardMaterial3D
            if original != null:
                var material := original.duplicate() as StandardMaterial3D
                visual.set_surface_override_material(surface, material)
                _materials.append(material)
                _base_colors.append(material.albedo_color)

func set_detail_level(level: int) -> void:
    var strength := clampf(float(level - 1) / 2.0, 0.0, 1.0)
    for i in _materials.size():
        _materials[i].albedo_color = _base_colors[i].lerp(Color(0.18, 0.20, 0.24), strength * 0.78)
    for detail in _detail_meshes:
        detail.visible = level < 3

func on_picked_up(owner_node: Node) -> void:
    _grab_owner = owner_node
    grabbed.emit(self)

func on_released() -> void:
    _grab_owner = null
    reset_to_start()

func reset_to_start() -> void:
    if is_instance_valid(_grab_owner):
        var previous_owner := _grab_owner
        _grab_owner = null
        previous_owner._release()
    freeze = false
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    global_transform = _base_transform

func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_grab_owner) and global_position.distance_to(_base_transform.origin) > 0.02:
        reset_to_start()
