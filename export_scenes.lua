-- export_scenes.lua
-- 用 Lune 运行:  lune run export_scenes.lua   (在 MonsterRush 目录下)
-- 作用: 读取两个场景的 .rbxl 文件, 把代码与代码相关的结构导出到 export/<场景名>/ 下:
--   - Script/LocalScript/ModuleScript -> .lua 文件 (脚本带子脚本 -> 文件夹/init.<ext> + 子文件)
--   - 轻量容器(ScreenGui/Frame/TextButton/RemoteEvent 等) -> <name>.model.json 保留类名与关键属性
--   - 重量级内容(零件/网格/人形模型等) -> 只导出其中的脚本作参考, 不写入项目映射
--   - 自动生成 default.project.json (只映射可完整回同步的容器, 避免 Rojo 同步时误删未导出内容)
-- 说明: remodel 已停止维护(0.11.0 读不了新版 .rbxl), Lune 是官方推荐的替代品。
-- 注意: Lune 的 GetChildren()/GetDescendants() 返回的表可能带空洞, 必须用 pairs() 遍历, 不能用 ipairs()。

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SCRIPT_EXT = {
	Script = ".server.lua",
	LocalScript = ".client.lua",
	ModuleScript = ".lua",
}

-- =====================【导出配置】=====================
-- 方式一(推荐): 手动指定要导出的文件。
--   把 .rbxl 放进本目录, 然后在下面加一行:
--     { file = "文件名.rbxl", name = "输出文件夹名", label = "备注" }
local PLACES = {
	{ file = "MonsterRush.rbxl", name = "MonsterRush", label = "主场景" },
	{ file = "RushMap.rbxl", name = "RushMap", label = "子场景(地图)" },
}

-- 方式二: 自动扫描。把上面的 PLACES 清空(改成 PLACES = {}),
--   运行后会自动导出当前目录下所有 .rbxl 到 export/<文件名>/;
--   需要跳过某些文件时, 把文件名加进下面的 SKIP_FILES。
local SKIP_FILES = {
	-- "不要导出.rbxl",
}
-- ====================================================

local function collectPlaces()
	if #PLACES > 0 then
		return PLACES
	end
	local found = {}
	for _, name in ipairs(fs.readDir(".")) do
		if name:match("%.rbxl$") then
			local skip = false
			for _, s in ipairs(SKIP_FILES) do
				if s == name then
					skip = true
					break
				end
			end
			if not skip then
				local base = name:gsub("%.rbxl$", "")
				found[#found + 1] = { file = name, name = base, label = base }
			end
		end
	end
	table.sort(found, function(a, b)
		return a.file < b.file
	end)
	return found
end

-- 轻量容器: 保留类名并导出关键属性 (Rojo model.json)
local MODEL_JSON_PROPS = {
	ScreenGui = { "Enabled", "ResetOnSpawn", "DisplayOrder", "ZIndexBehavior", "ScreenInsets" },
	Frame = { "Visible", "Position", "Size", "AnchorPoint", "Rotation", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ZIndex", "ClipsDescendants" },
	TextButton = { "Visible", "Position", "Size", "AnchorPoint", "Rotation", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ZIndex", "Text", "TextColor3", "TextSize", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment", "TextStrokeColor3", "TextStrokeTransparency", "AutoButtonColor", "RichText" },
	TextLabel = { "Visible", "Position", "Size", "AnchorPoint", "Rotation", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ZIndex", "Text", "TextColor3", "TextSize", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment", "TextStrokeColor3", "TextStrokeTransparency", "RichText" },
	TextBox = { "Visible", "Position", "Size", "AnchorPoint", "Rotation", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ZIndex", "Text", "TextColor3", "TextSize", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment", "TextStrokeColor3", "TextStrokeTransparency", "ClearTextOnFocus", "MultiLine" },
	ScrollingFrame = { "Visible", "Position", "Size", "AnchorPoint", "Rotation", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ZIndex", "ScrollBarThickness", "CanvasSize", "AutomaticCanvasSize", "CanvasPosition", "ScrollingDirection", "ScrollBarImageColor3", "ScrollBarImageTransparency", "ElasticBehavior" },
	ImageLabel = { "Visible", "Position", "Size", "AnchorPoint", "Rotation", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ZIndex", "Image", "ImageColor3", "ImageTransparency", "ScaleType", "TileSize", "ResampleMode" },
	ImageButton = { "Visible", "Position", "Size", "AnchorPoint", "Rotation", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ZIndex", "Image", "ImageColor3", "ImageTransparency", "ScaleType", "TileSize", "ResampleMode", "AutoButtonColor" },
	UICorner = { "CornerRadius" },
	UIStroke = { "Color", "Thickness", "Transparency", "ApplyStrokeMode", "LineJoinMode" },
	UIListLayout = { "Padding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "ItemLineAlignment" },
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UIGradient = { "Rotation", "Offset" },
	RemoteEvent = {},
	RemoteFunction = {},
	BindableEvent = {},
	BindableFunction = {},
}

-- 这些属性是 UDim 类型, Rojo model.json 不支持(AmbiguousValue 无对象变体), 跳过
local UDIM_PROPS = {
	CornerRadius = true,
	Padding = true,
	PaddingTop = true,
	PaddingBottom = true,
	PaddingLeft = true,
	PaddingRight = true,
}

-- 永不写入项目映射的服务: GUI 布局(Position/Size 等 UDim2)无法用 model.json 表示,
-- 映射会导致同步后 UI 全部归零错乱; 这类容器只导出作参考
local NEVER_MAP = {
	StarterGui = true,
}

-- 不需要 model.json 的类: 文件夹本身就是 Folder;
-- StarterPlayerScripts/StarterCharacterScripts 等 Rojo 会按文件夹名字自动识别
local NO_MODEL_JSON = {
	Folder = true,
	Configuration = true,
	StarterPlayerScripts = true,
	StarterCharacterScripts = true,
}

-- 重量级类: 无法用 Rojo 项目完整表示(零件/网格/人形等),
-- 含这些实例的子树只导出其中的脚本作参考, 不写入项目映射
local HEAVY_CLASSES = {
	Part = true,
	MeshPart = true,
	WedgePart = true,
	CornerWedgePart = true,
	CylinderPart = true,
	BallPart = true,
	SpecialMesh = true,
	Humanoid = true,
	Animator = true,
	HumanoidDescription = true,
	BodyColors = true,
	FaceControls = true,
	AccessoryDescription = true,
	BodyPartDescription = true,
	Animation = true,
	Attachment = true,
	Motor6D = true,
	Weld = true,
	WeldConstraint = true,
	BallSocketConstraint = true,
	HingeConstraint = true,
	AnimationConstraint = true,
	NoCollisionConstraint = true,
	WrapTarget = true,
	Terrain = true,
}

local function sanitizeName(name)
	return name:gsub('[\\/:*?"<>|]', "_")
end

local function countScripts(instance)
	local n = 0
	for _, d in pairs(instance:GetDescendants()) do
		if SCRIPT_EXT[d.ClassName] then
			n = n + 1
		end
	end
	return n
end

-- 子树是否含重量级内容
local function subtreeIsHeavy(instance)
	for _, d in pairs(instance:GetDescendants()) do
		if HEAVY_CLASSES[d.ClassName] then
			return true
		end
	end
	return false
end

local function jsonString(s)
	s = tostring(s)
	s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
	return '"' .. s .. '"'
end

local function jsonValue(v)
	local t = type(v)
	if t == "boolean" then
		return tostring(v)
	end
	if t == "number" then
		return string.format("%g", v)
	end
	if t == "string" then
		return jsonString(v)
	end
	if t == "table" then
		-- Vector/Color3: [x, y, z]
		if v.__vec then
			local parts = {}
			for i = 1, #v do
				parts[i] = jsonValue(v[i])
			end
			return "[" .. table.concat(parts, ", ") .. "]"
		end
		return "null"
	end
	return "null"
end

-- 把属性值编码成 Rojo model.json 可接受的形式
-- Rojo 7.x 只支持: bool / number / string / [x,y] / [x,y,z] / [x,y,z,w] / 12 数 CFrame / 枚举名
-- UDim2/UDim/Font/ColorSequence 等复杂类型不支持, 返回 nil 跳过
local function encodeValue(v, propName)
	local t = type(v)
	if t == "boolean" or t == "number" then
		return v
	end
	if t == "string" then
		return v
	end
	if t == "userdata" then
		local s = tostring(v)
		-- 枚举: Enum.TextXAlignment.Center -> Center
		if s:match("^Enum%.") then
			return s:match("([^%.]+)$")
		end
		-- 数值列表: UDim2 "0, 100, 0, 200" / Color3 "0, 0, 0" / Vector2 "0, 0"
		local parts = {}
		for num in s:gmatch("[%-%d%.eE]+") do
			parts[#parts + 1] = tonumber(num)
		end
		if #parts == 4 then
			-- UDim2: 不支持, 跳过 (会丢失 Position/Size 等布局)
			return nil
		elseif #parts == 3 then
			return { __vec = true, parts[1], parts[2], parts[3] }
		elseif #parts == 2 then
			if UDIM_PROPS[propName] then
				return nil -- UDim: 不支持, 跳过
			end
			return { __vec = true, parts[1], parts[2] }
		end
		return nil
	end
	return nil -- 复杂类型(Font 等)暂不导出
end

-- 给轻量容器写 <name>.model.json(放在同名文件夹旁边)
local function writeModelJson(instance, outDir)
	local className = instance.ClassName
	local props = {}
	for _, p in ipairs(MODEL_JSON_PROPS[className] or {}) do
		local ok, v = pcall(function()
			return instance[p]
		end)
		if ok then
			local enc = encodeValue(v, p)
			if enc ~= nil then
				props[p] = enc
			end
		end
	end
	local json = '{\n  "className": ' .. jsonString(className)
	local keys = {}
	for k in pairs(props) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	if #keys > 0 then
		json = json .. ',\n  "properties": {'
		for i, k in ipairs(keys) do
			json = json .. (i > 1 and "," or "") .. "\n    " .. jsonString(k) .. ": " .. jsonValue(props[k])
		end
		json = json .. "\n  }"
	end
	json = json .. "\n}"
	local path = outDir .. "/" .. sanitizeName(instance.Name) .. ".model.json"
	fs.writeFile(path, json)
	return path
end

local stats = { scripts = 0, dirs = 0 }

-- 递归导出: 把 instance 下的内容按层级写入 outDir
-- 轻量子树(无零件/模型等)整体导出; 重量级子树只导出含脚本的部分作参考
local function exportSubtree(instance, outDir, log)
	fs.writeDir(outDir)
	stats.dirs = stats.dirs + 1
	for _, child in pairs(instance:GetChildren()) do
		local ext = SCRIPT_EXT[child.ClassName]
		if ext then
			local source = tostring(child.Source)
			local childScripts = countScripts(child)
			local name = sanitizeName(child.Name)
			if childScripts > 0 then
				-- 脚本自身还挂着子脚本: 按 Rojo 惯例导出成 文件夹/init.<ext>
				local dir = outDir .. "/" .. name
				fs.writeDir(dir)
				local initPath = dir .. "/init" .. ext
				fs.writeFile(initPath, source)
				stats.scripts = stats.scripts + 1
				print("  [脚本] " .. initPath)
				log[#log + 1] = initPath
				exportSubtree(child, dir, log)
			else
				local filePath = outDir .. "/" .. name .. ext
				fs.writeFile(filePath, source)
				stats.scripts = stats.scripts + 1
				print("  [脚本] " .. filePath)
				log[#log + 1] = filePath
			end
		elseif not subtreeIsHeavy(child) then
			-- 轻量实例: 整体导出(文件夹递归; 其他类写 model.json 保留类名)
			if not NO_MODEL_JSON[child.ClassName] then
				local jsonPath = writeModelJson(child, outDir)
				print("  [容器] " .. jsonPath)
				log[#log + 1] = jsonPath
			end
			exportSubtree(child, outDir .. "/" .. sanitizeName(child.Name), log)
		elseif countScripts(child) > 0 then
			-- 重量级内容(零件/模型等): 只导出其中的脚本作参考
			print("  [参考] " .. child.Name .. " 含重量级内容(零件/模型), 只导出脚本, 不映射")
			exportSubtree(child, outDir .. "/" .. sanitizeName(child.Name), log)
		end
	end
end

-- 生成 default.project.json: 只映射"完整可回同步"的服务
-- (服务子树内含重量级内容 -> 不映射, 避免 Rojo 同步时删除未导出的零件等)
local function generateProjectJson(placeName, services)
	local entries = {}
	for _, svc in ipairs(services) do
		entries[#entries + 1] = "    " .. jsonString(svc.name) .. ': { "$path": ' .. jsonString("src/" .. svc.name) .. " }"
	end
	local json = '{\n  "name": ' .. jsonString(placeName) .. ',\n  "tree": {\n    "$className": "DataModel"'
	if #entries > 0 then
		json = json .. ",\n" .. table.concat(entries, ",\n")
	end
	json = json .. "\n  }\n}\n"
	return json
end

for _, place in ipairs(collectPlaces()) do
	print("======================================")
	print("读取场景: " .. place.label .. " -> " .. place.file)
	local data = fs.readFile(place.file)
	local game = roblox.deserializePlace(data)
	print("读取成功! DataModel: " .. game.Name)
	stats.scripts = 0
	stats.dirs = 0
	local log = {}
	local outRoot = "export/" .. place.name .. "/src"
	-- 重导出前清空旧输出, 避免残留已删除的脚本文件
	pcall(function()
		fs.removeDir(outRoot)
	end)
	local services = {}
	local unmapped = {}
	local expected = 0
	for _, service in pairs(game:GetChildren()) do
		local n = countScripts(service)
		if n > 0 or SCRIPT_EXT[service.ClassName] then
			expected = expected + n
			if SCRIPT_EXT[service.ClassName] then
				expected = expected + 1
			end
			local serviceDir = outRoot .. "/" .. service.Name
			print("导出容器: " .. service.Name .. " (含脚本 " .. n .. "+1)")
			exportSubtree(service, serviceDir, log)
			if subtreeIsHeavy(service) then
				unmapped[#unmapped + 1] = service.Name
				print("  ! " .. service.Name .. " 含重量级内容, 不写入项目映射(仅参考)")
			elseif NEVER_MAP[service.Name] then
				unmapped[#unmapped + 1] = service.Name
				print("  ! " .. service.Name .. " 的 UI 布局无法用 model.json 表示, 不写入项目映射(仅参考)")
			else
				services[#services + 1] = { name = service.Name }
			end
		end
	end
	-- 写 default.project.json
	local projectJson = generateProjectJson(place.name, services)
	fs.writeFile("export/" .. place.name .. "/default.project.json", projectJson)
	-- 写导出清单
	local mappedNames = {}
	for _, s in ipairs(services) do
		mappedNames[#mappedNames + 1] = s.name
	end
	local summary = "场景: " .. place.label .. " (" .. place.file .. ")\n"
	summary = summary .. "脚本总数: " .. stats.scripts .. " (预期 " .. expected .. ")\n"
	summary = summary .. "已映射进 Rojo 项目的容器: " .. (#mappedNames > 0 and table.concat(mappedNames, ", ") or "无") .. "\n"
	summary = summary .. "未映射(仅参考, 含零件/模型等): " .. (#unmapped > 0 and table.concat(unmapped, ", ") or "无") .. "\n"
	summary = summary .. "导出时间: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"
	fs.writeFile("export/" .. place.name .. "/导出清单.txt", summary .. table.concat(log, "\n"))
	local match = (stats.scripts == expected) and "✓ 数量一致" or "✗ 数量不一致!"
	print(("导出完成: %s 共 %d 个脚本 (预期 %d) %s"):format(place.name, stats.scripts, expected, match))
end
print("全部完成!")
