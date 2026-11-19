class_name SlicePanel
extends RefCounted
var host

func _init(scene: Node3D) -> void:
	host = scene

func state() -> CampaignState: return host.session.state

func locked() -> bool:
	var s := state()
	var a := s.running()
	return s.mode != "active" or s.slice.phase != "" or (a != null and a.kind in ["transfer","slice"])

func guide() -> void:
	host.show_panel("Личный план","До уединения посетите красный навес. У Ло Вэя есть конечные набор сбора, сосуд и трактат. У зелёного навеса Шэнь Юй обучает травничеству и алхимии.\n\nУ бледных цветов осмотрите след, обследуйте корень и выберите способ извлечения. У западной гряды распознайте кварц. Обработка частей и выдержка дают стабилизатор. Целый корень или пилюля сохраняют путь ускоренной конденсации.\n\nСравните способы в имуществе. У переправы отправьтесь на дальний берег. В камере наращивайте накопление и закрепляйте малые ступени. После Основания вернитесь на торговый двор. Тайник у мастерской можно подготовить до опасной вылазки.",{"Имущество и процессы":host.material_ui.inventory})

func inheritance() -> void:
	var s := state()
	var opts := {}
	if not s.slice.buried: opts["Спрятать 24 камня, набор, сосуд и знак при наличии"] = preview.bind("bury")
	elif s.slice.inner > 0: opts["Осмотреть и забрать содержимое"] = preview.bind("unearth")
	if not s.slice.sensitive: opts["Развить чувствительность · 4 камня / 2 года"] = preview.bind("sensitivity")
	host.show_panel("Тайник у старой мастерской","Снаружи поместятся 8 камней, внутри — 16, свободный набор и сосуд со всем содержимым. Место останется в памяти. Оставленное имущество сразу перестаёт быть доступным в пути.",opts)

func main() -> void:
	var s := state()
	var p := s.slice
	var a := s.running()
	var stage := SliceWorld.STAGES.find(s.body().milestone)
	var opts := {}
	var text := "%s · %s\nДуша %d/%d лет · тело %d/%d лет · %d камней\n%s" % [WorldCalendar.label(s.day),SliceWorld.NAMES[stage],WorldCalendar.age_years(0,s.day),s.soul.limit_years,WorldCalendar.age_years(s.body().born,s.body().died if not s.body().alive else s.day),s.body().limit_years,s.materials.wallet,p.result]
	var title := "Долина Белой Осоки"
	if p.carrier != "first": text += "\nСовместимость: %s. Пределы здоровья / Ци: %d / %d." % ["холодная" if p.carrier=="cold" else "тёплая",SliceWorld.vitals(s).hp,SliceWorld.vitals(s).qi]
	if p.unstable: text += "\nНестабильная Ци: %d · распад %s." % [p.unstable,WorldCalendar.label(p.decay)]
	if s.mode == "ended":
		title = "Путь души завершён"
	elif a != null and a.kind in ["slice","transfer"]:
		title = "Перенос души" if a.kind == "transfer" else "Уединение"
		text += "\nПройдено %d из %d дней. Окончание %s." % [a.progress,a.duration,WorldCalendar.label(s.day+a.duration-a.progress)]
		opts["Продвинуть один день"] = advance.bind(1)
		opts["Завершить этап"] = advance.bind(a.duration-a.progress)
	elif s.mode == "body_dead":
		title = "Тело погибло"
		text += "\nНосимые вещи остались у погибшего тела. Знания и приобретённое мастерство сохранились. Поиск носителя займёт пять лет общей жизни мира."
		opts["Начать перенос души"] = preview.bind("transfer")
	elif p.phase != "":
		title = "Камера первого Основания"
		text += "\nСпособ: %s." % ("Плавное закрепление" if p.method.begins_with("smooth") else "Конденсация")
		match p.phase:
			"entry": opts["Ввести первую часть средств"] = preview.bind("infuse")
			"wave":
				opts["Сохранить резерв и принять нагрузку"] = preview.bind("endure")
				if not SliceWorld.reserved(s,["stabilizer"]).is_empty(): opts["Использовать резервную дозу"] = preview.bind("reserve")
				if p.method == "condense": opts["Выравнивание · дополнительный год"] = preview.bind("align")
			"final":
				if not p.load: opts["Закрепить Основание"] = preview.bind("finish")
				else:
					if p.method.begins_with("smooth"): opts["Снять нагрузку · ещё два года"] = preview.bind("extend")
					opts["Удержать частичный контур · нестабильная Ци"] = preview.bind("unstable")
					opts["Форсировать · риск тяжёлой травмы"] = preview.bind("force")
		opts["Контролируемое прекращение"] = preview.bind("stop")
	else:
		if stage < 4 and s.exploration.place == SedgeWorld.BANK:
			title = "Уединение на дальнем берегу"
			if not p.pool: opts["Накопить Ци"] = preview.bind("gather")
			elif stage < 3:
				opts["Уравновесить поток и пройти малую ступень"] = preview.bind("minor")
				opts["Попытаться перейти без выравнивания"] = preview.bind("risk_minor")
			else: opts["Начать первый великий прорыв"] = preview.bind("begin")
		if s.exploration.place == SedgeWorld.YARD:
			opts["Спуститься к камнеедам"] = enter_ravine
		opts["Имущество и процессы"] = host.material_ui.inventory
		opts["Личный план"] = guide
		opts["Путевой журнал"] = host.journal
	opts["Сохранить и выйти"] = host.leave
	host.show_panel(title,text,opts)

func enter_ravine() -> void:
	host.show_panel("Тропа к водосбросу","Внизу обитают молодой и рогатый камнееды. Короткий выход может обвалиться. Безопасная площадка позади вас позволяет вернуться через меню паузы.",{"Войти в ущелье":switch_ravine})

func switch_ravine() -> void:
	if host.integrated.switch_area("ravine"):
		host.get_tree().change_scene_to_file(SliceSession.RAVINE)
	else: host.show_panel("Тропа недоступна",host.session.error)

func preview(cmd: String) -> void:
	var s := state()
	var candidate := StateCodec.clone(s)
	var reason := SliceWorld.apply(candidate,cmd,true)
	if reason != "":
		host.show_panel("Условия действия",reason,{"Вернуться":main})
		return
	var a := candidate.running()
	var end := s.day+a.duration if a != null else s.day
	var projected: int = candidate.materials.wallet-s.materials.wallet
	var text := "Дата после этапа: %s. Изменение кошелька: %+d камней." % [WorldCalendar.label(end),projected]
	match cmd:
		"begin": text += "\nКамера стоит 4 камня. Плавное закрепление: пять лет, возможны ещё два. Конденсация: два года, с выравниванием три. После введения материалы расходуются без возврата. Незавершённый контур даёт только временную Ци."
		"infuse": text += "\nБудут внесены препарат или целый корень, первый кварц и камни первой стадии."
		"finish","force","unstable","extend": text += "\nРасходуются оставшиеся камни метода, при конденсации также второй кварц."
		"risk_minor": text += "\nБез выравнивания переход может сорваться. Накопление сохранится."
		"transfer": text += "\nНовое тело начнёт с ранней Ци. Личные обязательства прежнего тела завершены."
	if cmd == "force": text += "\nКонтур перегружен. Повреждение рёбер и потеря 35 здоровья. При 35 здоровья или меньше тело погибнет."
	var fatal := end >= s.soul_expiry() or (s.body().alive and end >= s.body_expiry())
	if fatal: text += "\nИзвестный предел будет достигнут прежде окончания: %s." % ("кампания завершится" if end >= s.soul_expiry() else "тело погибнет")
	host.show_panel("Подтвердить решение",text,{"Принять известный исход" if fatal else "Подтвердить":execute.bind(cmd,fatal),"Отменить":main})

func execute(cmd: String,fatal: bool) -> void:
	if not host.integrated.play(cmd,fatal):
		host.show_panel("Действие недоступно",host.session.error)
		return
	host.land.sync(state())
	main()

func advance(days: int) -> void:
	if not host.session.advance(days):
		host.failure()
		return
	host.enter()
	main()
