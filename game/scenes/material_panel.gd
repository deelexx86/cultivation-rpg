class_name MaterialPanel
extends RefCounted
## Presentation only: every consequence goes through SedgeSession.
const LABELS := {"kit":"Набор сбора", "vessel":"Герметичный сосуд", "treatise":"Учебный трактат", "root":"Целый живой корень", "root_part":"Повреждённая часть корня", "quartz":"Фрагмент глухого кварца", "tainted_quartz":"Загрязнённый кварц", "essence":"Стабилизированный полуфабрикат", "unstable_essence":"Нестабильная эссенция", "spent_essence":"Выдохшаяся эссенция", "stabilizer":"Доза стабилизатора", "pill":"Пилюля конденсации"}
const RECIPES := {"divide":"Разделить целый корень", "stabilize":"Бережная стабилизация", "force":"Ускоренный прогрев", "repair":"Исправить нестабильность", "mature":"Автономная выдержка", "clean":"Очистить кварц", "order":"Заказать стабилизацию"}
var scene

func _init(host: Node3D) -> void: scene = host
func state() -> CampaignState: return scene.session.state

func item_name(raw: Dictionary) -> String:
	return "%s №%s" % [LABELS[raw.kind],raw.id.get_slice(".",2)]

func run(command: String, argument: String = "") -> void:
	if not scene.session.material(command,argument):
		scene.show_panel("Действие недоступно",scene.session.error)
		return
	scene.land.sync(state())
	if state().running() != null:
		work()
	else:
		var message := "Расходы и результат сохранены."
		if command == "extract":
			message = "Живой контур сохранён: доступна конденсация или переработка." if argument.begins_with("root.") and state().materials.root == "intact" else "Получены две части. Возраст и происхождение сохранены; живой контур нарушен. Части пригодны для стабилизации." if argument.begins_with("root.") else "Источник уменьшился на один фрагмент. Монолит остался на месте."
		if command == "choose": message = "План сохранён, материалы и камни зарезервированы. Прорыв ещё не начат; расходы попытки не списаны. Можно освободить подготовку и выбрать другой способ."
		scene.show_panel("Материальная подготовка",message,{"Имущество и процессы":inventory,"Следующий шаг":guide})

func guide() -> void:
	scene.show_panel("P3 · Личный план","1. Купите набор, сосуд и трактат у красного навеса.\n2. У зелёного навеса Шэнь Юй: травничество (4 года) и алхимия по трактату (6 лет).\n3. Бледные цветы к северо-востоку: осмотр → духовное обследование → способ добычи.\n4. Светлая порода к западу от тропы: осмотр → распознавание → наружные фрагменты.\n5. Вернитесь к зелёному навесу. Обработайте часть или закажите стабилизацию, затем выдержите полуфабрикат. Во время автономной работы практикуйтесь.\n6. Выберите подготовку: плавное закрепление принимает дозу из повреждённого корня; конденсации нужен целый живой корень или конечная покупная пилюля.\nJ — журнал; Esc — имущество, процессы и помощь. Годы расходуются только после подтверждения.",{"Сравнить способы":methods,"Имущество и процессы":inventory})

func shop() -> void:
	var s := state()
	var prefix := "lo." if s.person(SedgeWorld.LO).alive else "yin."
	var options := {}
	var lines := "Камни духа: %d (зарезервировано %d). Запас конечный.\n" % [s.materials.wallet,s.materials.pledged]
	if prefix == "yin." and s.day < WorldCalendar.ordinal(24): lines += "Поставка готовых препаратов ожидается к году 24.\n"
	for key: String in P3Content.data().offers:
		if not key.begins_with(prefix): continue
		var offer: Dictionary = P3Content.data().offers[key]
		lines += "%s · %d камней · осталось %d\n" % [LABELS[offer.kind],offer.price,s.materials.stock[key]]
		if s.materials.stock[key] > 0: options["Купить: %s · %d" % [LABELS[offer.kind],offer.price]] = run.bind("buy",key)
	options["Продать материал"] = sell_menu
	options["Разговор о медном знаке"] = scene.interact.bind("merchant")
	scene.show_panel("Лавка · Ло Вэй" if prefix == "lo." else "Лавка · Инь Цю",lines,options)

func mentor() -> void:
	var options := {"Травничество · 8 камней / 4 года":training.bind("herbalism"),"Алхимия и оба способа · трактат / 6 лет":training.bind("alchemy"),"Обработка и заказы":recipes,"Сравнить способы подготовки":methods}
	options["Оставить сосуд с содержимым на хранении"] = run.bind("stash","")
	options["Забрать сосуд с хранения"] = run.bind("retrieve","")
	if not state().person(MaterialWorld.MENTOR).alive:
		options.erase("Травничество · 8 камней / 4 года")
		options.erase("Алхимия и оба способа · трактат / 6 лет")
		scene.show_panel("Мастерская · новый исполнитель","Шэнь Юй умер. Его личные уроки завершились, но мастерская продолжает принятые заказы по прежним условиям. Материалы и готовые результаты остаются у своих владельцев.",options)
		return
	scene.show_panel("Шэнь Юй · зелёный навес","«Знать место мало. Научись видеть живые волокна и структуру породы. Приобретённый трактат ещё нужно освоить».\nОбучение занимает героя. Работа мастерской и выдержка идут параллельно на общей дате. Продажи и уединение не создают новых ресурсов.",options)

func forecast(days: int) -> String:
	var s := state()
	var end := s.day+days
	var soul_age := WorldCalendar.age_years(s.soul.born,end)
	var body_age := WorldCalendar.age_years(s.body().born,end)
	return "Завершение: %s.\nДуша: %d / %d лет; тело: %d / %d лет.\nИзвестные личные обещания могут истечь; пожилые знакомые могут не дождаться. Нестабильная эссенция теряет пригодность через 365 дней после создания; герметичный сосуд сохраняет остальное сырьё в пределах этого профиля." % [WorldCalendar.label(end),soul_age,s.soul.limit_years,body_age,s.body().limit_years]

func training(key: String) -> void:
	var def: Dictionary = P3Content.data().training[key]
	var days := WorldCalendar.add_years(state().day,def.years)-state().day
	scene.show_panel("Подтвердить обучение","Цена: %d камней, %d лет. Трактат остаётся вещью; освоенное знание сохраняется в душе.\n%s" % [def.price,def.years,forecast(days)],{"Начать обучение":run.bind("learn",key)})

func root() -> void:
	var s := state()
	var options := {}
	if not s.exploration.notes.has("observe."+str(s.exploration.source)):
		options["Осмотреть физический след"] = scene.act.bind("observe")
	else: options["Духовное обследование и распознавание"] = run.bind("inspect","root")
	if s.materials.notes.has("root.recognized."+str(s.exploration.source)) and s.materials.root == "standing":
		options["Бережно отделить части · без живого контура"] = extraction.bind("root.careful")
		options["Попытаться извлечь целиком · риск повреждения"] = extraction.bind("root.whole")
	var status := "Растение на месте. Начальное травничество распознаёт его, но целое извлечение ещё рискованно." if s.materials.root == "standing" else "Источник извлечён. Повторный вход и новое обследование его не восстановят."
	scene.show_panel("Стеклянный корень · старица",status+"\nОколо 600 лет — происхождение, а не оценка целостности. Нужны травничество, нож из набора и герметичный сосуд.",options)

func mineral() -> void:
	var s := state()
	var options := {"Осмотреть / распознать породу":run.bind("inspect","quartz")}
	if s.materials.notes.has("quartz.recognized"):
		options["Выделить наружный фрагмент"] = extraction.bind("quartz.surface")
		options["Грубо вскрыть оболочку · загрязнение"] = extraction.bind("quartz.rough")
		options["Оценить внутренний монолит"] = run.bind("extract","quartz.core")
	scene.show_panel("Глухой кварц · западная гряда","Осталось наружных фрагментов: %d / 6. Алхимия распознаёт структуру. Наружная часть доступна без боя; внутренний монолит требует иной операции.\nГрубое вскрытие снижает энергию и требует очистки. Очищенный остаток годится для плавного метода." % s.materials.quartz_left,options)

func extraction(method: String) -> void:
	var risk := "Бережное разделение даст две пригодные части. Целый живой контур будет утрачен." if method == "root.careful" else "Травничества достаточно для попытки, но не для уверенной работы. Возможны целый живой корень либо повреждение отростков и две пригодные части. Повторить попытку с тем же корнем нельзя." if method == "root.whole" else "Один чистый наружный фрагмент, без потери энергии." if method == "quartz.surface" else "Один загрязнённый фрагмент со сниженной энергией. Потребуется очистка; энергия не восстановится."
	scene.show_panel("Подтвердить извлечение",risk+"\nКалендарь не сдвигается. Набор и сосуд остаются. Сырьё поступит в сосуд: вместимость 8 единиц.",{"Подтвердить способ":run.bind("extract",method)})

func inventory() -> void:
	var s := state()
	var lines := "Камни: %d; свободно %d. Груз %.1f / %.1f кг.\n" % [s.materials.wallet,s.materials.wallet-s.materials.pledged,MaterialWorld.weight(s)/1000.0,P3Content.data().carry_grams/1000.0]
	for raw: Dictionary in s.materials.items:
		if raw.holder in ["consumed","merchant"]: continue
		lines += "%s%s\n" % [item_name(raw)," · зарезервировано" if raw.reserved != "" else " · на хранении" if raw.holder == "court.cache" else ""]
	for row: Dictionary in s.materials.jobs:
		var title: String = "Обучение" if row.recipe.begins_with("learn.") else RECIPES[row.recipe]
		var status: String = {"running":"в работе","ready":"готово" if row.known or row.executor == "self" else "готовность не проверена","claimed":"получено","cancelled":"отменено","stopped":"остановлено"}[row.status]
		lines += "%s · %s · %s\n" % [title,WorldCalendar.label(row.due),status]
	if s.materials.method != "": lines += "План: %s. Резерв камней: %d.\n" % [{"smooth":"Плавный","smooth-reserve":"Плавный с резервом","condense":"Конденсация"}[s.materials.method],s.materials.pledged]
	scene.show_panel("Имущество и работа",lines,{"Свойства и происхождение":details,"Текущие процессы":processes,"Сравнить способы":methods,"Маршрут P3":guide})

func details() -> void:
	var options := {}
	for raw: Dictionary in state().materials.items:
		if raw.holder not in ["consumed","merchant"]: options[item_name(raw)] = detail.bind(raw.id)
	scene.show_panel("Материалы","Выберите экземпляр. Происхождение и текущее состояние учитываются отдельно.",options)

func detail(id: String) -> void:
	var raw := MaterialWorld.item(state(),id)
	var origin := "Старица Белой осоки" if raw.origin == MaterialWorld.ROOT else "Западная гряда" if raw.origin == MaterialWorld.QUARTZ else "Конечная поставка торговца"
	var place := "Мастерская / процесс" if raw.holder.begins_with("p3.job.") else "Сосуд на хранении у зелёного навеса" if raw.holder == "court.cache" else "В вашем сосуде" if raw.container != "" else "При себе"
	var parents := PackedStringArray()
	for parent: String in raw.parents: parents.append(item_name(MaterialWorld.item(state(),parent)))
	scene.show_panel(item_name(raw),"Источник: %s · возраст происхождения около %d лет\nЦелостность: %s · чистота: %s · энергия: %s\nМесто: %s · %s\nИсходное сырьё: %s" % [origin,raw.age,{"whole":"целое","part":"часть","damaged":"повреждено"}[raw.integrity],{"clean":"чисто","tainted":"примеси"}[raw.purity],{"retained":"сохранена","reduced":"снижена","unstable":"нестабильна"}[raw.energy],place,"зарезервировано" if raw.reserved != "" else "свободно",", ".join(parents) if not parents.is_empty() else "добыча / поставка"])

func recipes() -> void:
	var options := {}
	for key: String in P3Content.data().recipes: options[RECIPES[key]] = recipe_inputs.bind(key)
	scene.show_panel("Мастерская · обработка","Небольшой набор операций. Стабилизация → полуфабрикат → 30 дней выдержки → доза для плавного метода. Ускоренный прогрев даёт исправимый дефект.\nЗанятые сырьё и оснащение нельзя использовать второй раз. При заказе сосуд остаётся у вас.",options)

func recipe_inputs(key: String) -> void:
	var def: Dictionary = P3Content.data().recipes[key]
	var options := {}
	for id: String in MaterialWorld.available(state(),def.input): options[item_name(MaterialWorld.item(state(),id))] = recipe_preview.bind(key,id)
	scene.show_panel(RECIPES[key],"Выберите свободное сырьё: %s. Если списка нет, материал отсутствует или уже занят." % LABELS[def.input],options)

func recipe_preview(key: String, id: String) -> void:
	var def: Dictionary = P3Content.data().recipes[key]
	var mode: String = {"active":"Вы заняты: набор и сосуд зарезервированы. Безопасной отмены нет; выход сохраняет текущий прогресс.","autonomous":"Автономно: вы свободны, набор и сосуд заняты до получения результата. При отмене после начала сырьё становится нестабильным.","workshop":"Заказ мастерской: сырьё передаётся мастерской, вы свободны. Организация продолжает работу при смене мастера. Цена не возвращается; отмена до начала возвращает сырьё, позднее — нестабильный полуфабрикат. Получение лично при визите."}[def.mode]
	var risk := " Ускоренный нагрев заведомо оставляет нестабильность; нужно исправление за 1 камень / 3 дня до истечения 365 дней." if key == "force" else " Освоенная работа с подходящим сырьём даёт объявленный результат без дополнительного броска провала."
	scene.show_panel(RECIPES[key],"%s → %d × %s. Цена %d камней; срок %d дней.\n%s%s\n%s" % [item_name(MaterialWorld.item(state(),id)),def.quantity,LABELS[def.output],def.fee,def.days,mode,risk,forecast(def.days)],{"Подтвердить работу":run.bind("recipe."+key,id)})

func processes() -> void:
	var options := {}
	for row: Dictionary in state().materials.jobs:
		if row.status == "ready" and (row.executor == "self" or row.known): options["Получить: "+str(RECIPES[row.recipe])+" №"+row.id.get_slice(".",2)] = run.bind("claim",row.id)
		if row.status == "running" and row.recipe in ["order","mature"]: options["Отменить: "+str(RECIPES[row.recipe])+" №"+row.id.get_slice(".",2)] = cancel_preview.bind(row.id)
	options["Практиковаться 30 дней параллельно"] = practice.bind(30)
	scene.show_panel("Процессы","Автономная готовность наступает на общей дате без визита. Прогулка, меню и время вне игры её не приближают. Личный контроль исключает другие занятия.",options)

func cancel_preview(id: String) -> void:
	scene.show_panel("Прекратить процесс","До начала возвращается исходное сырьё. После начала — нестабильная эссенция; её нужно исправить до истечения 365 дней. Оплата заказа не возвращается. Готовый результат не выдаётся.",{"Подтвердить отмену":run.bind("cancel",id)})

func practice(days: int) -> void:
	var plan := Simulation.preview(state(),days,0)
	scene.show_panel("Практика · параллельная работа",forecast(days)+"\nКультивация и автономная работа идут в те же дни, без сложения сроков. Ступень и предел жизни в P3 не меняются.",{"Подтвердить практику":begin_practice.bind(plan)})

func begin_practice(plan: Dictionary) -> void:
	if scene.session.confirm(plan,"p3.practice.%d" % state().revision): work()
	else: scene.failure()

func work() -> void:
	var active := state().running()
	if active == null:
		for action: CampaignState.Action in state().actions:
			if action.status == "paused" and action.kind != "travel":
				scene.show_panel("Работа прервана","Достигнутая дата, затраты и частичный прогресс сохранены. Другое личное занятие недоступно до разрешения остановки.",{"Продолжить работу":resume.bind(action.id),"Сохранить и выйти":scene.leave})
				return
	if active == null:
		inventory()
		return
	scene.show_panel("Длительное действие","Пройдено %d / %d дней. Расходы уже сохранены.\n%s" % [active.progress,active.duration,forecast(active.duration-active.progress)],{"Продвинуть 1 день":advance.bind(1),"Завершить оставшуюся работу":advance.bind(active.duration-active.progress),"Сохранить и выйти":scene.leave})

func resume(id: String) -> void:
	if scene.session.resume(id,"p3.resume.%d" % state().revision): work()
	else: scene.failure()

func advance(days: int) -> void:
	if not scene.session.advance(days):
		scene.failure()
		return
	scene.refresh()
	if state().running() != null: work()
	else:
		scene.land.sync(state())
		var description := "Фактическая дата: %s. Результат, освоение и расходы сохранены." % WorldCalendar.label(state().day)
		if not state().materials.jobs.is_empty() and state().materials.jobs.back().status == "stopped": description = "Работа остановлена на фактической дате %s. Совершённые расходы и частичный прогресс сохранены; неосвоенное знание не выдано. Личный урок не может продолжиться без живого наставника." % WorldCalendar.label(state().day)
		scene.show_panel("Этап завершён",description,{"Имущество и процессы":inventory,"Вернуться к мастеру":mentor})

func sell_menu() -> void:
	var options := {}
	for raw: Dictionary in state().materials.items:
		if raw.holder == state().body().id and raw.reserved == "" and P3Content.data().sell.has(raw.kind): options["%s · %d камней" % [item_name(raw),P3Content.data().sell[raw.kind]]] = run.bind("sell",raw.id)
	scene.show_panel("Продажа","Проданный экземпляр переходит торговцу. Бесплатного выкупа, обновления сырья и бесконечного производства нет.",options)

func methods() -> void:
	var body := "Плавное закрепление · 5 лет, возможно ещё 2. Нужны 1 доза стабилизатора, 1 чистый кварц, 4 камня и камера за 4. Можно добавить дозу резерва. Принимает обработанные повреждённые части. Возможны нагрузка, продление или прекращение; результат — устойчивое простое Основание.\n\nКонденсация · 2 года, либо 3 с выравниванием. Нужны целый живой корень / готовая пилюля, 2 кварца с сохранённой энергией, 8 камней и камера за 4. Повреждённые части не подходят. Быстрее, но дороже и опаснее: нагрузка, травма, при критическом продолжении — гибель. Дополнительная сила автоматически не выдаётся.\n\nЭто материальный план P3. До реальной попытки нужны совершенство Ци, заполненное накопление и устойчивое тело (поздний этап). Здесь материалы резервируются, календарь и предел жизни не меняются."
	scene.show_panel("Два способа · первый великий переход",body,{"Подготовить плавный способ":run.bind("choose","smooth"),"Плавный способ + доза резерва":run.bind("choose","smooth-reserve"),"Подготовить конденсацию":run.bind("choose","condense"),"Освободить подготовку":run.bind("choose","")})
