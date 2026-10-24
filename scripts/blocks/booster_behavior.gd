class_name BoosterBehavior
extends BlockBehavior
## 喷射器（真物理推力）：长按喷射键，沿组件朝向持续施力，
## 带尾焰粒子（世界空间拖尾）+ 火光。推力按底盘重量自动整定。

const TWR := 1.6  # 每个喷射器推重比（同底盘多喷射器均摊，与轮数无关）

var dir_local := Vector3(0, 0, -1)
var nozzle_local := Vector3.ZERO
var _thrust := 100.0
var flame: CPUParticles3D
var smoke: CPUParticles3D
var flare: OmniLight3D


func setup_booster(chassis_: RigidBody3D, cell_world: Vector3, dir_world: Vector3,
        thrust_per: float) -> void:
    chassis = chassis_
    dir_local = chassis.basis.inverse() * dir_world.normalized()
    nozzle_local = cell_world - chassis.position
    _thrust = thrust_per
    _build_fx()


func _build_fx() -> void:
    var sim_node: Node = chassis.get_parent()
    if sim_node == null:
        return
    flame = CPUParticles3D.new()
    flame.name = "BoosterFlame"
    flame.amount = 70
    flame.lifetime = 0.45
    flame.explosiveness = 0.0
    flame.spread = 6.0
    flame.initial_velocity_min = 9.0
    flame.initial_velocity_max = 13.0
    flame.gravity = Vector3.ZERO
    flame.scale_amount_min = 0.5
    flame.scale_amount_max = 1.0
    flame.direction = Vector3(0, 0, -1)
    var flame_mesh := BoxMesh.new()
    flame_mesh.size = Vector3(0.14, 0.14, 0.14)
    var fm := StandardMaterial3D.new()
    fm.albedo_color = Color(1.0, 0.72, 0.25)
    fm.emission_enabled = true
    fm.emission = Color(1.0, 0.55, 0.15)
    fm.emission_energy_multiplier = 4.0
    flame_mesh.material = fm
    flame.mesh = flame_mesh
    flame.emitting = false
    sim_node.add_child(flame)

    smoke = CPUParticles3D.new()
    smoke.name = "BoosterSmoke"
    smoke.amount = 40
    smoke.lifetime = 1.3
    smoke.spread = 12.0
    smoke.initial_velocity_min = 3.0
    smoke.initial_velocity_max = 5.5
    smoke.gravity = Vector3(0, 1.2, 0)
    smoke.scale_amount_min = 0.6
    smoke.scale_amount_max = 1.6
    smoke.direction = Vector3(0, 0, -1)
    var smoke_mesh := BoxMesh.new()
    smoke_mesh.size = Vector3(0.22, 0.22, 0.22)
    var sm := StandardMaterial3D.new()
    sm.albedo_color = Color(0.92, 0.88, 0.82, 0.55)
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_mesh.material = sm
    smoke.mesh = smoke_mesh
    smoke.emitting = false
    sim_node.add_child(smoke)

    flare = OmniLight3D.new()
    flare.name = "BoosterFlare"
    flare.light_color = Color(1.0, 0.6, 0.25)
    flare.light_energy = 0.0
    flare.omni_range = 6.0
    sim_node.add_child(flare)


func _physics_process(delta: float) -> void:
    if chassis == null or flame == null:
        return
    var v := axis_value("throttle")
    if sim and sim.reverse_forward:
        v = -v
    var active := absf(v) > 0.01
    if not active:
        flame.emitting = false
        smoke.emitting = false
        flare.light_energy = 0.0
        return
    var dir := (chassis.global_basis * dir_local).normalized()
    var nozzle: Vector3 = chassis.to_global(nozzle_local) + dir * 0.32
    chassis.apply_central_force(dir * v * _thrust)
    # 尾焰：世界空间定位 + 朝向喷射反方向（喷射方向接近竖直时换参考轴，避免 look_at 失效）
    var exhaust := -dir
    var up := Vector3.UP if absf(exhaust.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
    flame.global_position = nozzle
    flame.look_at(nozzle + exhaust, up)
    flame.emitting = true
    smoke.global_position = nozzle + exhaust * 0.4
    smoke.look_at(nozzle + exhaust, up)
    smoke.emitting = true
    flare.position = nozzle + exhaust * 0.2
    flare.light_energy = 2.6 + randf() * 1.2
