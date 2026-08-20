extends RefCounted
## 相机跟随/回位的共享数学工具。
## 探索（house）与战斗（battle）两套镜头共用这些函数，避免重复实现与相互漂移。


static func smooth_factor(rate: float, delta: float) -> float:
	## 指数平滑系数：rate 越大收敛越快；与帧率无关。
	return 1.0 - exp(-rate * delta)


static func screen_up_offset(camera: Camera3D, size_ratio: float) -> Vector3:
	## 把"屏幕上方"方向映射到世界偏移：沿相机局部 Y（屏幕向上）平移
	## size_ratio × 当前正交视野，使焦点内容落在画幅偏下（偏下构图）。
	if camera == null:
		return Vector3.ZERO
	return camera.global_transform.basis.y * (camera.size * size_ratio)


static func angle_toward(current: float, target: float, weight: float) -> float:
	## 沿最短角差向 target 插值（处理角度环绕）。
	return lerp_angle(current, target, weight)
