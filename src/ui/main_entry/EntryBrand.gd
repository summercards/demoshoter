extends Control
## 启动页品牌图形（棱镜线框版）：左侧「弹壳风暴-青春版」白线字标 + 贯穿细线。
## 全部用 Control._draw 自绘（中文使用默认系统字体，无需外部字体资源）。
##
## 旧版（斜切 + 青色/品红霓虹发光 + 呼吸脉冲）按规范 §11 反面清单移除：
## 棱镜语言零辉光、零渐变，字标只保留近白正文 + 一条天蓝强调（语义色）与结构细线。
##
## ⚠️ 2026-10-21 改名（弹壳风暴2 → 弹壳风暴-青春版）后字标必须**自适应缩放**：
## 原版是「弹壳风暴」4 字 + 强调「2」1 字，base = h×0.44 = 78px 时总宽 371，
## 容器可用宽 390，刚好塞下。新串是 4 字 + 强调「青春版」3 字，同 base 下总宽 562，
## **溢出 172px**。字数一变，任何写死的 base 都会翻车 —— 所以改成
## 「先按设计基准量宽，超了就按 avail/need 回缩，并**迭代到收敛**」：
##   need = w(正文) + base×gap + w(强调)   ；need > avail 时 base ← base × (avail/need) × 0.995
## 必须迭代：`int(base)` 取整 + hinting 让字宽不严格线性，实测缩一次仍会溢出 3.48px。
## 这样加字、删字都不出框，且不需要每次改名字重新试字号。

const BRAND_TEXT := "弹壳风暴"
## 强调段：天蓝色，是字标里唯一的彩色（语义强调，不作装饰）。
const BRAND_ACCENT := "青春版"
## 正文与强调之间的间距，以字号为基准的比例（不是绝对像素，缩放后仍然成立）。
const ACCENT_GAP_RATIO := 0.18
## 收缩迭代上限。见 `_fit_base()` 的说明：只缩一次**不收敛**，必须迭代。
const FIT_ITERATIONS := 4

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## 解出「字标刚好落在可用宽内」的字号。
##
## ⚠ 不能只按 `avail/need` 缩一次就完事 —— 实测：base 78.32 时 need 580.10 / avail 390，
## 缩一次到 52.65 后**仍溢出 3.48px**。原因是 `int(base)` 取整 + 字体 hinting 让
## 字宽不随字号严格线性，比例公式不收敛。
## 所以这里是迭代：每轮重量、超了就再乘 `avail/need`（并留 0.5% 余量防止在边界上抖动），
## 最多 4 轮；正常情况下第 1~2 轮就收敛。
func _fit_base(font: Font, base: float, avail: float) -> Dictionary:
	var title_w := font.get_string_size(BRAND_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, int(base)).x
	var accent_w := font.get_string_size(BRAND_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, -1, int(base)).x
	for _i in FIT_ITERATIONS:
		var gap := base * ACCENT_GAP_RATIO
		var need := title_w + gap + accent_w
		if need <= avail or need <= 0.0:
			break
		base *= avail / need * 0.995
		title_w = font.get_string_size(BRAND_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, int(base)).x
		accent_w = font.get_string_size(BRAND_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, -1, int(base)).x
	return {"base": base, "title_w": title_w, "accent_w": accent_w}


func _draw() -> void:
	var h := size.y
	if h <= 4.0:
		return
	var font := UIStyleFactory.make_prism_font(4)
	if font == null:
		font = _font()
	if font == null:
		return
	var start_x := 12.0
	# 可用宽：扣掉左起偏移与右侧 6px 收尾，细线也按这个宽度走，字标与细线右端对齐。
	var avail := size.x - start_x - 6.0
	var fitted := _fit_base(font, h * 0.44, avail)
	var base: float = fitted["base"]
	var title_w: float = fitted["title_w"]
	var baseline := h * 0.50
	# 字标：近白正文 + 天蓝强调（唯一彩色，起强调作用，不作装饰铺陈）。
	draw_string(
		font, Vector2(start_x, baseline), BRAND_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(base), UIPalette.PRISM_TEXT
	)
	draw_string(
		font, Vector2(start_x + title_w + base * ACCENT_GAP_RATIO, baseline), BRAND_ACCENT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(base), UIPalette.PRISM_ACCENT
	)
	# 结构细线：字标下方一条贯穿白线 + 一条更短的次级弱线。
	var rule_y := baseline + base * 0.24
	var rule_w := size.x - start_x - 6.0
	draw_rect(Rect2(start_x, rule_y, rule_w, 1.0), Color(1.0, 1.0, 1.0, 0.30), true)
	draw_rect(Rect2(start_x, rule_y + 7.0, rule_w * 0.40, 1.0), Color(1.0, 1.0, 1.0, 0.14), true)
	# 左侧 2px 竖线：与常驻 HUD 的引导竖线同构，表明"这一块属于品牌区"。
	draw_rect(Rect2(start_x - 9.0, h * 0.10, 2.0, h * 0.34), Color(1.0, 1.0, 1.0, 0.55), true)


func _font() -> Font:
	var f := get_theme_font("font")
	if f == null:
		f = ThemeDB.fallback_font
	return f
