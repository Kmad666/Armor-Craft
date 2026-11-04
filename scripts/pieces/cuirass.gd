extends Node3D
## Cuirass traced from a front / side / back reference, fitted to the wooden
## mannequin (measurements.json).
##
##   Breastplate  mid section, front: round chest, wide shallow neckline,
##                armholes, shoulder tabs
##   Backplate    mid section, back
##   Fauld        bottom section: one flared band all round, below the waist
##   Shoulders    leather straps riveted to the front and back tabs, joining
##                them over each shoulder
##   Belt         front belt on the division with buckle and hanging tail,
##                plus buckled straps across each side seam
##
## The shell is a ring surface whose width (front and back views) and depth
## (side view) at every height come straight from the traced outlines (T_*
## tables), at one uniform scale. The shape follows the reference only; it is
## not adjusted to the mannequin. Neck and armholes are cut out along smooth
## curves with marching-triangle clipping, and every cut edge gets a rolled edge.
##
## Axes: +Y up, +Z toward the front. Angle a = 0 is the front centre,
## positive a turns toward +X (the figure's left).

const K := preload("res://scripts/mesh_kit.gd")

# ---- traced from the reference sheet (front / side / back) -----------------
# One uniform scale for every axis (0.818 mm per pixel), so the proportions
# are the reference's own. Per height: ring half-width, armhole cut
# half-width in the front and back views, z of the front and back
# silhouettes in the side view, and z of the side seam (widest point).
const T_Y := [1.5073, 1.5032, 1.4991, 1.4950, 1.4909, 1.4868, 1.4827, 1.4786, 1.4746, 1.4705, 1.4664, 1.4623, 1.4582, 1.4541, 1.4500, 1.4459, 1.4418, 1.4377, 1.4337, 1.4296, 1.4255, 1.4214, 1.4173, 1.4132, 1.4091, 1.4050, 1.4009, 1.3968, 1.3928, 1.3887, 1.3846, 1.3805, 1.3764, 1.3723, 1.3682, 1.3641, 1.3600, 1.3559, 1.3519, 1.3478, 1.3437, 1.3396, 1.3355, 1.3314, 1.3273, 1.3232, 1.3191, 1.3150, 1.3110, 1.3069, 1.3028, 1.2987, 1.2946, 1.2905, 1.2864, 1.2823, 1.2782, 1.2741, 1.2701, 1.2660, 1.2619, 1.2578, 1.2537, 1.2496, 1.2455, 1.2414, 1.2373, 1.2332, 1.2292, 1.2251, 1.2210, 1.2169, 1.2128, 1.2087, 1.2046, 1.2005, 1.1964, 1.1923, 1.1883, 1.1842, 1.1801, 1.1760, 1.1719, 1.1678, 1.1637, 1.1596, 1.1555, 1.1514, 1.1474, 1.1433, 1.1392, 1.1351, 1.1310, 1.1269, 1.1228, 1.1187, 1.1146, 1.1105, 1.1065, 1.1024, 1.0983, 1.0942, 1.0901, 1.0860, 1.0819, 1.0778, 1.0737, 1.0696, 1.0656, 1.0615, 1.0574, 1.0533, 1.0492, 1.0451, 1.0410, 1.0369, 1.0328, 1.0287, 1.0247]
const T_RX := [0.1371, 0.1413, 0.1453, 0.1471, 0.1466, 0.1446, 0.1422, 0.1405, 0.1400, 0.1399, 0.1402, 0.1412, 0.1431, 0.1450, 0.1464, 0.1479, 0.1494, 0.1504, 0.1513, 0.1524, 0.1534, 0.1543, 0.1554, 0.1565, 0.1571, 0.1575, 0.1580, 0.1587, 0.1594, 0.1602, 0.1610, 0.1618, 0.1625, 0.1630, 0.1635, 0.1642, 0.1652, 0.1662, 0.1670, 0.1679, 0.1686, 0.1695, 0.1705, 0.1719, 0.1734, 0.1746, 0.1753, 0.1750, 0.1741, 0.1727, 0.1710, 0.1691, 0.1675, 0.1660, 0.1648, 0.1636, 0.1625, 0.1613, 0.1601, 0.1589, 0.1575, 0.1561, 0.1548, 0.1536, 0.1524, 0.1513, 0.1502, 0.1491, 0.1480, 0.1470, 0.1461, 0.1452, 0.1443, 0.1434, 0.1424, 0.1416, 0.1408, 0.1401, 0.1397, 0.1397, 0.1403, 0.1410, 0.1413, 0.1411, 0.1405, 0.1398, 0.1393, 0.1394, 0.1399, 0.1404, 0.1411, 0.1422, 0.1437, 0.1453, 0.1469, 0.1484, 0.1500, 0.1516, 0.1531, 0.1547, 0.1563, 0.1585, 0.1618, 0.1657, 0.1690, 0.1711, 0.1726, 0.1735, 0.1739, 0.1735, 0.1731, 0.1732, 0.1735, 0.1721, 0.1672, 0.1578, 0.1438, 0.1270, 0.1122]
# backplate flatness per height (superellipse exponent), fitted so the
# armhole's back rim lands where it sits in the side view
const T_NB := [6.3501, 6.3501, 6.6303, 7.4816, 9.1397, 11.2104, 12.8685, 13.7198, 14.0000, 13.9104, 13.5393, 12.7745, 11.7032, 10.7003, 10.0090, 9.4864, 9.0160, 8.6657, 8.4420, 8.2984, 8.1414, 7.9434, 7.8047, 7.7733, 7.8281, 7.9185, 8.0004, 8.0565, 8.0985, 8.0749, 8.0204, 8.0053, 8.0945, 8.2908, 8.5971, 8.9028, 9.1983, 9.5095, 9.7090, 9.6395, 9.3643, 9.0176, 8.6837, 8.3084, 7.9368, 7.6524, 7.3246, 6.6621, 5.7429, 4.9792, 4.8413, 5.2946, 5.8727, 6.2152, 6.3249, 6.2839, 6.2174, 6.1318, 6.0367, 5.9388, 5.8409, 5.7430, 5.6451, 5.5471, 5.4492, 5.3513, 5.2534, 5.1555, 5.0575, 4.9596, 4.8617, 4.7638, 4.6659, 4.5679, 4.4700, 4.3721, 4.2749, 4.1827, 4.1035, 4.0466, 4.0152, 4.0029, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000, 4.0000]
const T_XF := [0.1321, 0.1411, 0.1460, 0.1444, 0.1436, 0.1411, 0.1368, 0.1364, 0.1358, 0.1358, 0.1350, 0.1350, 0.1346, 0.1346, 0.1344, 0.1344, 0.1346, 0.1346, 0.1346, 0.1350, 0.1352, 0.1358, 0.1362, 0.1370, 0.1374, 0.1380, 0.1389, 0.1399, 0.1407, 0.1415, 0.1427, 0.1440, 0.1450, 0.1464, 0.1481, 0.1495, 0.1511, 0.1528, 0.1546, 0.1564, 0.1587, 0.1607, 0.1630, 0.1658, 0.1685, 0.1714, 0.1738, 0.1740, 0.1726, 0.1714, 0.1703, 0.1689, 0.1681, 0.1669, 0.1656, 0.1644, 0.1632, 0.1622, 0.1611, 0.1599, 0.1587, 0.1573, 0.1562, 0.1550, 0.1538, 0.1526, 0.1517, 0.1507, 0.1493, 0.1485, 0.1476, 0.1468, 0.1460, 0.1448, 0.1442, 0.1431, 0.1423, 0.1417, 0.1409, 0.1405, 0.1425, 0.1425, 0.1431, 0.1421, 0.1421, 0.1389, 0.1409, 0.1413, 0.1419, 0.1427, 0.1421, 0.1438, 0.1454, 0.1470, 0.1485, 0.1501, 0.1515, 0.1530, 0.1546, 0.1562, 0.1579, 0.1591, 0.1624, 0.1691, 0.1716, 0.1730, 0.1744, 0.1757, 0.1763, 0.1759, 0.1738, 0.1742, 0.1761, 0.1765, 0.1726, 0.1638, 0.1517, 0.1362, 0.1164]
const T_XB := [0.1231, 0.1350, 0.1440, 0.1472, 0.1460, 0.1444, 0.1389, 0.1382, 0.1382, 0.1387, 0.1382, 0.1382, 0.1382, 0.1382, 0.1384, 0.1384, 0.1387, 0.1389, 0.1389, 0.1391, 0.1395, 0.1399, 0.1403, 0.1407, 0.1413, 0.1417, 0.1423, 0.1429, 0.1438, 0.1444, 0.1456, 0.1462, 0.1472, 0.1483, 0.1497, 0.1509, 0.1526, 0.1538, 0.1554, 0.1573, 0.1593, 0.1611, 0.1634, 0.1656, 0.1683, 0.1710, 0.1730, 0.1732, 0.1718, 0.1703, 0.1693, 0.1677, 0.1667, 0.1652, 0.1636, 0.1626, 0.1620, 0.1603, 0.1595, 0.1579, 0.1564, 0.1546, 0.1534, 0.1521, 0.1511, 0.1497, 0.1489, 0.1476, 0.1464, 0.1454, 0.1444, 0.1436, 0.1427, 0.1419, 0.1405, 0.1399, 0.1391, 0.1384, 0.1378, 0.1370, 0.1384, 0.1405, 0.1401, 0.1401, 0.1401, 0.1399, 0.1366, 0.1370, 0.1378, 0.1387, 0.1387, 0.1403, 0.1419, 0.1436, 0.1452, 0.1468, 0.1485, 0.1501, 0.1517, 0.1530, 0.1546, 0.1560, 0.1577, 0.1658, 0.1681, 0.1697, 0.1712, 0.1722, 0.1730, 0.1722, 0.1697, 0.1714, 0.1730, 0.1734, 0.1689, 0.1583, 0.1425, 0.1205, 0.0857]
const T_ZF := [-0.0274, -0.0221, -0.0176, -0.0131, -0.0090, -0.0049, -0.0008, 0.0041, 0.0098, 0.0164, 0.0225, 0.0282, 0.0290, 0.0311, 0.0339, 0.0372, 0.0401, 0.0434, 0.0466, 0.0499, 0.0524, 0.0556, 0.0585, 0.0614, 0.0642, 0.0671, 0.0695, 0.0724, 0.0748, 0.0773, 0.0798, 0.0822, 0.0843, 0.0867, 0.0892, 0.0908, 0.0928, 0.0949, 0.0965, 0.0990, 0.1006, 0.1023, 0.1039, 0.1055, 0.1067, 0.1080, 0.1096, 0.1104, 0.1117, 0.1125, 0.1137, 0.1145, 0.1153, 0.1157, 0.1162, 0.1166, 0.1170, 0.1174, 0.1174, 0.1170, 0.1170, 0.1166, 0.1166, 0.1162, 0.1157, 0.1153, 0.1145, 0.1141, 0.1137, 0.1129, 0.1125, 0.1117, 0.1108, 0.1100, 0.1092, 0.1084, 0.1076, 0.1063, 0.1055, 0.1043, 0.1035, 0.1023, 0.1010, 0.0998, 0.0990, 0.0973, 0.0961, 0.0961, 0.0994, 0.1010, 0.1018, 0.1027, 0.1018, 0.1018, 0.1010, 0.0994, 0.1006, 0.1018, 0.1027, 0.1035, 0.1043, 0.1051, 0.1067, 0.1076, 0.1080, 0.1092, 0.1100, 0.1108, 0.1117, 0.1125, 0.1141, 0.1149, 0.1149, 0.1157, 0.1166, 0.1137, 0.1149, 0.1129, 0.1051]
const T_ZB := [-0.0982, -0.1006, -0.1051, -0.1088, -0.1129, -0.1162, -0.1190, -0.1215, -0.1231, -0.1247, -0.1264, -0.1272, -0.1280, -0.1288, -0.1297, -0.1305, -0.1313, -0.1321, -0.1321, -0.1329, -0.1333, -0.1337, -0.1342, -0.1346, -0.1350, -0.1354, -0.1354, -0.1354, -0.1354, -0.1354, -0.1346, -0.1346, -0.1346, -0.1342, -0.1337, -0.1337, -0.1329, -0.1329, -0.1321, -0.1321, -0.1313, -0.1305, -0.1301, -0.1297, -0.1288, -0.1280, -0.1272, -0.1264, -0.1256, -0.1247, -0.1239, -0.1227, -0.1215, -0.1207, -0.1198, -0.1190, -0.1174, -0.1166, -0.1153, -0.1141, -0.1133, -0.1117, -0.1108, -0.1100, -0.1084, -0.1076, -0.1059, -0.1051, -0.1043, -0.1027, -0.1018, -0.1002, -0.0994, -0.0986, -0.0973, -0.0961, -0.0953, -0.0945, -0.0937, -0.0928, -0.0928, -0.0920, -0.0920, -0.0920, -0.0920, -0.0928, -0.0928, -0.0937, -0.0941, -0.0953, -0.0969, -0.0986, -0.1002, -0.1023, -0.1035, -0.1055, -0.1072, -0.1088, -0.1104, -0.1121, -0.1137, -0.1157, -0.1174, -0.1190, -0.1207, -0.1227, -0.1243, -0.1264, -0.1280, -0.1297, -0.1317, -0.1346, -0.1354, -0.1333, -0.1256, -0.1112, -0.0834, -0.0405, -0.0029]
const T_ZMID := [-0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0454, -0.0175, 0.0133]
# neckline: |x| -> height of the cut (front and back views)
const NECK_F := [[0.0000, 1.4664], [0.0327, 1.4695], [0.0413, 1.4712], [0.0487, 1.4727], [0.0542, 1.4744], [0.0589, 1.4761], [0.0636, 1.4779], [0.0677, 1.4798], [0.0714, 1.4816], [0.0748, 1.4832], [0.0775, 1.4850], [0.0806, 1.4867], [0.0834, 1.4884], [0.0857, 1.4902], [0.0879, 1.4919], [0.0904, 1.4936], [0.0922, 1.4949], [0.0945, 1.4961], [0.0957, 1.4976], [0.0973, 1.4989], [0.0986, 1.5003], [0.0998, 1.5018], [0.1038, 1.5300], [0.1200, 1.6000]]
const NECK_B := [[0.0000, 1.4733], [0.0364, 1.4767], [0.0462, 1.4785], [0.0542, 1.4802], [0.0601, 1.4819], [0.0661, 1.4835], [0.0710, 1.4853], [0.0755, 1.4868], [0.0793, 1.4883], [0.0828, 1.4899], [0.0861, 1.4915], [0.0888, 1.4930], [0.0914, 1.4944], [0.0937, 1.4956], [0.0959, 1.4969], [0.0973, 1.4982], [0.0990, 1.4995], [0.0998, 1.5010], [0.1038, 1.5300], [0.1200, 1.6000]]
# hem: |x| -> height of the lower edge (front and back views)
const HEM_F := [[0.0029, 1.0148], [0.0127, 1.0148], [0.0225, 1.0148], [0.0323, 1.0157], [0.0421, 1.0157], [0.0520, 1.0165], [0.0618, 1.0165], [0.0716, 1.0173], [0.0814, 1.0189], [0.0912, 1.0197], [0.1010, 1.0214], [0.1109, 1.0230], [0.1207, 1.0247], [0.1305, 1.0263], [0.1403, 1.0287], [0.1501, 1.0312], [0.1599, 1.0345], [0.1698, 1.0394], [0.1730, 1.0410]]
const HEM_B := [[0.0029, 1.0197], [0.0127, 1.0197], [0.0225, 1.0197], [0.0323, 1.0206], [0.0421, 1.0206], [0.0520, 1.0214], [0.0618, 1.0214], [0.0716, 1.0222], [0.0814, 1.0230], [0.0912, 1.0238], [0.1010, 1.0255], [0.1109, 1.0263], [0.1207, 1.0279], [0.1305, 1.0296], [0.1403, 1.0320], [0.1501, 1.0337], [0.1599, 1.0369], [0.1697, 1.0410], [0.1730, 1.0443]]

const TOP := 1.5073
const ARM_BOTTOM := 1.2995   # armholes close below this
const SEAM_Y := 1.1351       # division between the mid and bottom sections
const SEAM_Z := -0.0454       # side seam where breast and back plates meet
const STRAP_Y := [1.2512, 1.0713]  # buckled side straps (plates, fauld)
const N_FRONT := 2.0       # breastplate cross-section: round
# (backplate cross-section: T_NB per height)
## Size and placement on the mannequin. The reference has no absolute size,
## so the whole cuirass is scaled uniformly about FIT_ANCHOR (proportions
## unchanged) and shifted forward to sit on the figure.
const FIT_SCALE := 1.08
const FIT_SHIFT := Vector3(0.0, 0.0, 0.011)
const FIT_ANCHOR := Vector3(0.0, 1.30, 0.0)
const BACK_TUCK := 0.1     # backplate runs this far (radians) under the breastplate at the seams

const EDGE_R := 0.0033     # rolled edge radius (cuts are pulled in by this)
const COLS := 144          # around the body
const ROW_STEP := 0.0036    # metres between rows

var metal: Material
var leather: Material
var brass: Material
var m: Dictionary = {}
var pieces := {}  # name -> Node3D
## Cut edges of each plate as [a, y, push] samples, for measuring against the sheet.
var edge_loops := {}

# dense per-height table, 1 mm spacing: see _row_at
var _tab := PackedFloat32Array()
const TAB_Y0 := 0.99
const TAB_N := 540
const STRIDE := 12
var _rivets: Array = []


func setup(mats: Dictionary, measurements: Dictionary, chest_joint: Node3D, pelvis_joint: Node3D) -> void:
	metal = mats["metal"]
	leather = mats["leather"]
	brass = mats["brass"]
	m = measurements
	_build_table()
	for n in ["Breastplate", "Backplate", "Shoulders", "Belt"]:
		pieces[n] = _piece(n, chest_joint)
	pieces["Fauld"] = _piece("Fauld", pelvis_joint)
	rebuild_all()


func _piece(piece_name: String, joint: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = piece_name
	joint.add_child(n)
	# modelled in reference space; placed on the mannequin by the fit transform
	n.global_transform = fit_transform()
	return n


func fit_transform() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * FIT_SCALE),
		FIT_ANCHOR * (1.0 - FIT_SCALE) + FIT_SHIFT)


func rebuild_all() -> void:
	_build_plate("Breastplate", 1)
	_build_plate("Backplate", -1)
	_build_fauld()
	_build_shoulder_straps()
	_build_belt()


# ==========================================================================
# Shape: tables, body model, surface
# ==========================================================================

static func _hermite(z: float, zs: Array, vs: Array) -> float:
	if zs[0] > zs[-1]:
		zs = zs.duplicate()
		vs = vs.duplicate()
		zs.reverse()
		vs.reverse()
	var n := zs.size()
	if z <= zs[0]:
		return vs[0]
	if z >= zs[n - 1]:
		return vs[n - 1]
	for i in n - 1:
		var z0: float = zs[i]
		var z1: float = zs[i + 1]
		if z <= z1:
			var t0: float = (vs[mini(i + 1, n - 1)] - vs[maxi(i - 1, 0)]) / (zs[mini(i + 1, n - 1)] - zs[maxi(i - 1, 0)])
			var t1: float = (vs[mini(i + 2, n - 1)] - vs[i]) / (zs[mini(i + 2, n - 1)] - zs[i])
			var h := z1 - z0
			var t := (z - z0) / h
			var t2 := t * t
			var t3 := t2 * t
			return (2 * t3 - 3 * t2 + 1) * vs[i] + (t3 - 2 * t2 + t) * h * t0 \
				+ (-2 * t3 + 3 * t2) * vs[i + 1] + (t3 - t2) * h * t1
	return vs[n - 1]


static func _lin(x: float, pts: Array) -> float:
	if x <= pts[0][0]:
		return pts[0][1]
	for i in pts.size() - 1:
		if x <= pts[i + 1][0]:
			var k: float = (x - pts[i][0]) / (pts[i + 1][0] - pts[i][0])
			return lerpf(pts[i][1], pts[i + 1][1], k)
	return 2.0


## Smooth maximum: exactly max(a, b) once they differ by more than k.
static func _smax(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return maxf(a, b) + h * h * k * 0.25


## Precomputes everything that depends only on height, at 1 mm spacing.
## Per row: ring half-width front/back, z front/back/middle, armhole cut
## half-width front/back, body half-width, body z front/back/centre, spare.
func _build_table() -> void:
	_tab.resize(TAB_N * STRIDE)
	var ty := T_Y.duplicate()
	var cols := []
	for col in [T_RX, T_XF, T_XB, T_ZF, T_ZB, T_ZMID, T_NB]:
		var a := PackedFloat32Array()
		for i in TAB_N:
			a.append(_hermite(TAB_Y0 + i * 0.001, ty, col))
		cols.append(_smooth(a, 6))
	for i in TAB_N:
		var y := TAB_Y0 + i * 0.001
		# below the armholes the cut never bites
		var ramp := 0.5 * smoothstep(ARM_BOTTOM + 0.003, ARM_BOTTOM - 0.012, y)
		var o := i * STRIDE
		_tab[o] = cols[0][i]
		_tab[o + 2] = cols[3][i]
		_tab[o + 3] = cols[4][i]
		_tab[o + 4] = cols[5][i]
		_tab[o + 5] = cols[1][i] + ramp
		_tab[o + 6] = cols[2][i] + ramp
		_tab[o + 7] = cols[6][i]


## Gaussian smoothing (radius in samples), holding the ends.
static func _smooth(a: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	var sigma := radius * 0.5
	for i in a.size():
		var sum := 0.0
		var wsum := 0.0
		for k in range(-radius, radius + 1):
			var j := clampi(i + k, 0, a.size() - 1)
			var w := exp(-0.5 * (k * k) / (sigma * sigma))
			sum += a[j] * w
			wsum += w
		out[i] = sum / wsum
	return out


func _row_at(y: float) -> PackedFloat32Array:
	var f := clampf((y - TAB_Y0) / 0.001, 0.0, TAB_N - 1.001)
	var i := int(f)
	var k := f - i
	var out := PackedFloat32Array()
	out.resize(STRIDE)
	for j in STRIDE:
		out[j] = lerpf(_tab[i * STRIDE + j], _tab[(i + 1) * STRIDE + j], k)
	return out


## Surface point at angle a, height y, pushed `push` metres outward.
## Front half is a superellipse of exponent N_FRONT, back half N_BACK; they
## meet at the side seam, the widest point of each cross-section.
func surface(a: float, y: float, push: float = 0.0, row: PackedFloat32Array = PackedFloat32Array()) -> Vector3:
	if row.is_empty():
		row = _row_at(y)
	var c := cos(a)
	var s := sin(a)
	var rx := row[0] + push
	var zmid := row[4]
	var x: float
	var z: float
	# polar form: a is the direction from the centre, the superellipse sets the
	# radius, so points stay evenly spread whether the section is round or flat
	var n := N_FRONT if c >= 0.0 else row[7]
	var r := 1.0 / pow(pow(absf(s), n) + pow(absf(c), n), 1.0 / n)
	x = rx * s * r
	if c >= 0.0:
		z = zmid + (row[2] - zmid + push) * c * r
	else:
		z = zmid + (zmid - row[3] + push) * c * r
	return Vector3(x, y, z)


## Angle on the front (or back) half where the surface reaches lateral position x.
func angle_for_x(x: float, y: float, front: bool) -> float:
	var lo := 0.0 if front else PI
	var hi := PI * 0.5
	var ax := absf(x)
	for _i in 30:
		var mid := (lo + hi) * 0.5
		if absf(surface(mid, y).x) < ax:
			if front: lo = mid
			else: hi = mid
		else:
			if front: hi = mid
			else: lo = mid
	return signf(x) * (lo + hi) * 0.5 if x != 0.0 else (0.0 if front else PI)


func normal_at(a: float, y: float, push: float = 0.0) -> Vector3:
	var e := 0.002
	var da := surface(a + e, y, push) - surface(a - e, y, push)
	var dy := surface(a, y + e, push) - surface(a, y - e, push)
	var n := da.cross(dy)
	if n.length_squared() < 1e-16:
		n = Vector3(sin(a), 0.0, cos(a))
	n = n.normalized()
	var p := surface(a, y, push)
	if n.dot(Vector3(p.x, 0.0, p.z - _row_at(y)[4])) < 0.0:
		n = -n
	return n


static func _lin_hold(x: float, pts: Array) -> float:
	if x <= pts[0][0]:
		return pts[0][1]
	for i in pts.size() - 1:
		if x <= pts[i + 1][0]:
			var k: float = (x - pts[i][0]) / (pts[i + 1][0] - pts[i][0])
			return lerpf(pts[i][1], pts[i + 1][1], k)
	return pts[pts.size() - 1][1]


## Height of the lower edge under a point at lateral position x.
func hem(x: float, front: bool) -> float:
	return _lin_hold(absf(x), HEM_F if front else HEM_B)


## Lower edge at angle a (traced front and back views).
func bottom(a: float) -> float:
	var p := surface(a, 1.03)
	return hem(p.x, cos(a) >= 0.0)


## Angle of the side seam on side sx (+1 / -1): the widest point of the
## cross-section, where the breast and back plates meet.
func seam_angle(sx: float, _y: float) -> float:
	return sx * PI * 0.5


# ==========================================================================
# Cut-out shell builder (marching triangles over the (angle, height) grid)
# ==========================================================================

## Cut function for the mid plates: > 0 means cut away.
func _cut_mid(p: Vector3, a: float, y: float, row: PackedFloat32Array, side: int) -> float:
	var c := cos(a)
	var ax := absf(p.x)
	var neck := y - (_lin(ax, NECK_F if c >= 0.0 else NECK_B) - EDGE_R)
	var w := (c + 1.0) * 0.5
	var arm := ax - (lerpf(row[6], row[5], w) - EDGE_R)
	var f := maxf(neck, arm)
	return f


func _cut_fauld(p: Vector3, a: float, y: float, _row: PackedFloat32Array, _side: int) -> float:
	return hem(p.x, cos(a) >= 0.0) + EDGE_R - y


## Builds a clipped surface; returns [mesh, boundary loops (arrays of [a, y])].
func _shell(y0: float, y1: float, push: float, cut: Callable, side: int,
		a_lo: float = -PI, a_hi: float = PI) -> Array:
	var rows := int(ceil((y1 - y0) / ROW_STEP)) + 1
	var ys := PackedFloat32Array()
	for r in rows:
		ys.append(lerpf(y0, y1, float(r) / (rows - 1)))
	# full ring wraps round; a partial span is an open grid with straight sides
	var wrap := is_equal_approx(a_hi - a_lo, TAU)
	var nc := COLS if wrap else int(ceil((a_hi - a_lo) / (TAU / COLS))) + 1
	var da := (a_hi - a_lo) / (nc if wrap else nc - 1)
	var cells := nc if wrap else nc - 1
	# grid values
	var gp := []        # positions
	var gf := PackedFloat32Array()
	for r in rows:
		var row := _row_at(ys[r])
		for c in nc:
			var a := a_lo + c * da
			var p := surface(a, ys[r], push, row)
			gp.append(p)
			gf.append(cut.call(p, a, ys[r], row, side))

	var params := []       # [a, y] per output vertex
	var vid := {}          # key -> output index
	var tris := PackedInt32Array()

	var grid_v := func(r: int, c: int) -> int:
		var key := "g%d_%d" % [r, c % nc]
		if not vid.has(key):
			vid[key] = params.size()
			params.append([a_lo + (c % nc) * da, ys[r]])
		return vid[key]

	# vertex where the cut crosses the edge between two grid corners
	var edge_v := func(r0: int, c0: int, r1: int, c1: int) -> int:
		var ka := "%d_%d" % [r0, c0 % nc]
		var kb := "%d_%d" % [r1, c1 % nc]
		var key := ("e" + ka + "|" + kb) if ka < kb else ("e" + kb + "|" + ka)
		if vid.has(key):
			return vid[key]
		var a0 := a_lo + c0 * da
		var a1 := a_lo + c1 * da
		var yy0 := ys[r0]
		var yy1 := ys[r1]
		var f0 := gf[r0 * nc + c0 % nc]
		var lo := 0.0
		var hi := 1.0
		for _i in 14:
			var mid := (lo + hi) * 0.5
			var am := lerpf(a0, a1, mid)
			var ym := lerpf(yy0, yy1, mid)
			var rw := _row_at(ym)
			var fm: float = cut.call(surface(am, ym, push, rw), am, ym, rw, side)
			if (fm > 0.0) == (f0 > 0.0):
				lo = mid
			else:
				hi = mid
		var t := (lo + hi) * 0.5
		vid[key] = params.size()
		params.append([lerpf(a0, a1, t), lerpf(yy0, yy1, t)])
		return vid[key]

	for r in rows - 1:
		for c in cells:
			var corners := [[r, c], [r, c + 1], [r + 1, c + 1], [r + 1, c]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var vs := []
				for k in 3:
					vs.append(corners[tri[k]])
				var fs := []
				for v in vs:
					fs.append(gf[v[0] * nc + v[1] % nc])
				if fs[0] > 0.0 and fs[1] > 0.0 and fs[2] > 0.0:
					continue
				var poly := PackedInt32Array()
				for k in 3:
					var va: Array = vs[k]
					var vb: Array = vs[(k + 1) % 3]
					var fa: float = fs[k]
					var fb: float = fs[(k + 1) % 3]
					if fa <= 0.0:
						poly.append(grid_v.call(va[0], va[1]))
					if (fa > 0.0) != (fb > 0.0):
						poly.append(edge_v.call(va[0], va[1], vb[0], vb[1]))
				for k in range(1, poly.size() - 1):
					tris.append_array([poly[0], poly[k], poly[k + 1]])

	# positions and normals
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for pr in params:
		verts.append(surface(pr[0], pr[1], push))
		norms.append(normal_at(pr[0], pr[1], push))
	# wind for Godot (clockwise front faces)
	var idx := PackedInt32Array()
	var edge_count := {}
	for i in range(0, tris.size(), 3):
		var i0 := tris[i]
		var i1 := tris[i + 1]
		var i2 := tris[i + 2]
		var g := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
		if g.length_squared() < 1e-14:
			continue
		if g.dot(norms[i0] + norms[i1] + norms[i2]) < 0.0:
			idx.append_array([i0, i1, i2])
		else:
			idx.append_array([i0, i2, i1])
		for e in [[i0, i1], [i1, i2], [i2, i0]]:
			var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
			edge_count[key] = edge_count.get(key, 0) + 1
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	# boundary edges -> chained loops of parameters
	var adj := {}
	for key in edge_count.keys():
		if edge_count[key] == 1:
			var k2: Vector2i = key
			adj[k2.x] = adj.get(k2.x, []) + [k2.y]
			adj[k2.y] = adj.get(k2.y, []) + [k2.x]
	var seen := {}
	var loops := []
	for start in adj.keys():
		if seen.has(start):
			continue
		var chain := [start]
		seen[start] = true
		var cur: int = start
		while true:
			var nxt := -1
			for nb in adj[cur]:
				if not seen.has(nb):
					nxt = nb
					break
			if nxt < 0:
				break
			seen[nxt] = true
			chain.append(nxt)
			cur = nxt
		var closed: bool = chain.size() > 2 and (adj[cur] as Array).has(start)
		var pts := []
		for v in chain:
			pts.append(params[v])
		if closed:
			pts.append(params[start])
		loops.append(pts)
	return [mesh, loops]


func _rolled_edges(root: Node3D, loops: Array, push: float, radius: float, skip: Callable) -> void:
	for lp in loops:
		var seg := PackedVector3Array()
		for pr in lp:
			if skip.call(pr[0], pr[1]):
				if seg.size() > 2:
					_add_mesh(root, K.tube(seg, radius, 6), metal)
				seg = PackedVector3Array()
				continue
			seg.append(surface(pr[0], pr[1], push) + normal_at(pr[0], pr[1], push) * radius * 0.4)
		if seg.size() > 2:
			_add_mesh(root, K.tube(seg, radius, 6), metal)


# ==========================================================================
# Pieces
# ==========================================================================

func _build_plate(piece_name: String, side: int) -> void:
	var root: Node3D = pieces[piece_name]
	_clear(root)
	var push := 0.0 if side > 0 else -0.0018  # back plate tucks under the breast
	# the seam sits at the widest point of every cross-section (a = +-90 deg)
	var lo := -PI * 0.5 if side > 0 else PI * 0.5 - BACK_TUCK
	var hi := PI * 0.5 if side > 0 else PI * 1.5 + BACK_TUCK
	var res: Array = _shell(SEAM_Y - 0.016, TOP, push, Callable(self, "_cut_mid"), side, lo, hi)
	_add_mesh(root, res[0], metal)
	edge_loops[piece_name] = [res[1], push]
	# rolled edges everywhere except the hidden bottom row
	var skip := func(_a: float, y: float) -> bool: return y < SEAM_Y - 0.01
	_rolled_edges(root, res[1], push, EDGE_R, skip)


func _build_fauld() -> void:
	var root: Node3D = pieces["Fauld"]
	_clear(root)
	var push := 0.002
	var res: Array = _shell(1.012, SEAM_Y + 0.004, push, Callable(self, "_cut_fauld"), 0)
	_add_mesh(root, res[0], metal)
	edge_loops["Fauld"] = [res[1], push]
	var hem := func(_a: float, y: float) -> bool: return y > SEAM_Y
	var top := func(_a: float, y: float) -> bool: return y < SEAM_Y
	_rolled_edges(root, res[1], push, EDGE_R, hem)   # hem
	_rolled_edges(root, res[1], push, 0.0022, top)   # top edge, under the belt
	# side seam lines on the flared band
	for sx in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for i in 13:
			var y := lerpf(bottom(PI * 0.5) + 0.008, SEAM_Y, i / 12.0)
			var a := seam_angle(sx, y)
			pts.append(surface(a, y, push) + normal_at(a, y, push) * 0.0012)
		_add_mesh(root, K.tube(pts, 0.0016, 5), metal)


## Leather straps riveted to the front and back shoulder tabs, over the top.
func _build_shoulder_straps() -> void:
	var root: Node3D = pieces["Shoulders"]
	_clear(root)
	_rivets = []
	var y_low := 1.452
	for sx in [-1.0, 1.0]:
		var shape := func(u: float, t: float) -> Vector3:
			var x := 0.111 + (u - 0.5) * 0.036
			return _strap_path(sx, x, y_low, t)
		var c := Vector3(sx * 0.11, 1.44, -0.05)
		_add_mesh(root, K.surface(shape, 0.0, 1.0, 4, 0.0, 1.0, 40, c), leather)
		# rivets near each end
		for t in [0.06, 0.94]:
			var p := _strap_path(sx, 0.111, y_low, t)
			var n := (p - c).normalized()
			_rivets.append(K.rivet_xform(p, n, 0.0085))
	_flush_rivets(root, brass)


## Path over the shoulder at lateral position x (unsigned), t: 0 front .. 1 back.
func _strap_path(sx: float, x: float, y_low: float, t: float) -> Vector3:
	var lift := 0.0058
	var front := func(y: float) -> Vector3:
		return surface(angle_for_x(sx * x, y, true), y, lift)
	var back := func(y: float) -> Vector3:
		return surface(angle_for_x(sx * x, y, false), y, lift)
	if t < 0.3:
		return front.call(lerpf(y_low, TOP, t / 0.3))
	if t > 0.7:
		return back.call(lerpf(TOP, y_low, (t - 0.7) / 0.3))
	var p0: Vector3 = front.call(TOP)
	var p3: Vector3 = back.call(TOP)
	var d0: Vector3 = (p0 - front.call(TOP - 0.01)).normalized()
	var d3: Vector3 = (p3 - back.call(TOP - 0.01)).normalized()
	var span := p0.distance_to(p3)
	var p1 := p0 + d0 * span * 0.45
	var p2 := p3 + d3 * span * 0.45
	var u := (t - 0.3) / 0.4
	var v := 1.0 - u
	return p0 * (v * v * v) + p1 * (3.0 * v * v * u) + p2 * (3.0 * v * u * u) + p3 * (u * u * u)


func _build_belt() -> void:
	var root: Node3D = pieces["Belt"]
	_clear(root)
	_rivets = []
	var by := SEAM_Y + 0.002
	var push := 0.006
	# belt across the front, from seam to seam
	var a_end := absf(seam_angle(1.0, by)) - 0.08
	var band := func(a: float, t: float) -> Vector3:
		return surface(a, by + lerpf(-0.008, 0.008, t), push)
	_add_mesh(root, K.surface(band, -a_end, a_end, 80, 0.0, 1.0, 2, Vector3(0, by, 0)), leather)
	for sx in [-1.0, 1.0]:
		_rivet_at(sx * a_end * 0.97, by, push + 0.001, 0.0065)
		_rivet_at(sx * (a_end - 0.06), by + 0.034, 0.0, 0.006)  # belt anchor on the plate
	# buckle and hanging tail
	var ab := 0.06
	_buckle(root, ab, by, push + 0.002, 0.024, 0.02)
	var tail := func(a: float, t: float) -> Vector3:
		var y := lerpf(by - 0.006, bottom(0.0) + 0.012, t)
		return surface(a, y, 0.002 + 0.0045)
	_add_mesh(root, K.surface(tail, ab - 0.05, ab + 0.05, 4, 0.0, 1.0, 16, Vector3(0, 1.08, 0)), leather)
	_rivet_at(ab, by - 0.016, 0.002 + 0.0055, 0.0055)
	# buckled straps across each side seam: one on the plates, one on the fauld
	for sx in [-1.0, 1.0]:
		for spec in [[STRAP_Y[0], 0.0035], [STRAP_Y[1], 0.002 + 0.0035]]:
			var y: float = spec[0]
			var pp: float = spec[1]
			var a0 := seam_angle(sx, y)
			var strap := func(a: float, t: float) -> Vector3:
				return surface(a, y + lerpf(-0.0085, 0.0085, t), pp)
			_add_mesh(root, K.surface(strap, a0 - 0.32, a0 + 0.32, 16, 0.0, 1.0, 2, Vector3(0, y, 0)), leather)
			_buckle(root, a0 + sx * 0.06 * signf(cos(a0) + 1.0), y, pp + 0.002, 0.021, 0.019)
			_rivet_at(a0 - 0.28, y, pp + 0.001, 0.006)
			_rivet_at(a0 + 0.28, y, pp + 0.001, 0.006)
	_flush_rivets(root, metal)


func _buckle(root: Node3D, a: float, y: float, push: float, w: float, h: float) -> void:
	var p := surface(a, y, push)
	var n := normal_at(a, y, push)
	var frame := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5 - 0.12
	tm.outer_radius = 0.5
	tm.rings = 16
	tm.ring_segments = 6
	frame.mesh = tm
	frame.material_override = brass
	frame.transform = Transform3D(K.surface_basis(n, Vector3(w, 0.006 / 0.12, h)), p)
	root.add_child(frame)
	var tongue := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w * 0.9, 0.0025, 0.0025)
	tongue.mesh = bm
	tongue.material_override = brass
	tongue.transform = Transform3D(K.surface_basis(n, Vector3.ONE), p + n * 0.0015)
	root.add_child(tongue)


# ==========================================================================
# Helpers
# ==========================================================================

func _rivet_at(a: float, y: float, push: float, d: float) -> void:
	_rivets.append(K.rivet_xform(surface(a, y, push), normal_at(a, y, push), d))


func _clear(root: Node3D) -> void:
	for c in root.get_children():
		c.queue_free()


func _add_mesh(root: Node3D, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)


func _flush_rivets(root: Node3D, mat: Material) -> void:
	if _rivets.size() > 0:
		root.add_child(K.multimesh(_rivets, K.rivet_mesh(), mat))
	_rivets = []
