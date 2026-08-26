extends Node


const FPS: float = 60.0
const ANGLE_CONVERSION: float = PI/180.0

enum RotationModes{
	STC = 0,
	LTR = 1,
	ARD = 2,
}

var CLIENTSIDE_PLAYER = null
