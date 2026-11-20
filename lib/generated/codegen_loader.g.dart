// DO NOT EDIT. This is code generated via package:easy_localization/generate.dart

// ignore_for_file: prefer_single_quotes, avoid_renaming_method_parameters, constant_identifier_names

import 'dart:ui';

import 'package:easy_localization/easy_localization.dart' show AssetLoader;

class CodegenLoader extends AssetLoader{
  const CodegenLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) {
    return Future.value(mapLocales[locale.toString()]);
  }

  static const Map<String,dynamic> _ar = {
  "app_name": "Guardian 360",
  "common": {
    "cancel": "إلغاء",
    "confirm": "تأكيد",
    "save": "حفظ",
    "edit": "تعديل",
    "delete": "حذف",
    "retry": "إعادة المحاولة",
    "loading": "جاري التحميل...",
    "success": "تمت العملية بنجاح",
    "error": "حدث خطأ",
    "back": "رجوع"
  },
  "greetings": {
    "morning": "صباح الخير،",
    "afternoon": "طاب مساؤك،",
    "evening": "مساء الخير،",
    "night": "مساء الخير،"
  },
  "home": {
    "title": "Guardian 360",
    "status_safe": "النظام آمن ومفعل",
    "status_ready": "النظام جاهز",
    "status_initializing": "جاري تهيئة النظام",
    "status_subtitle_safe": "جميع الحساسات تعمل بكفاءة",
    "status_subtitle_ready": "يمكنك تشغيل الحماية وبدء الرحلة",
    "status_subtitle_initializing": "جاري فحص وحدات الحماية الذكية.",
    "sos_button": "SOS",
    "sos_subtitle": "اضغط لطلب المساعدة",
    "card_kroka": "كروكة ذكية",
    "card_contacts": "جهات اتصال",
    "card_safe_arrival": "وصول آمن",
    "medical_incomplete_title": "السجل الطبي غير مكتمل",
    "medical_incomplete_body": "إكمال السجل الطبي يساعد فرق الإنقاذ على معرفة فصيلة الدم، الحساسية، الأدوية، والأمراض المزمنة. يمكنك إكماله الآن، أو إرسال نداء الاستغاثة فوراً إذا كانت الحالة طارئة.",
    "send_sos_now": "إرسال SOS الآن",
    "complete_medical": "إكمال السجل الطبي",
    "medical_required_title": "السجل الطبي مطلوب",
    "medical_required_fallback": "يجب استكمال السجل الطبي أولًا قبل استخدام الحماية أو الرحلات.",
    "later": "لاحقًا"
  },
  "notifications": {
    "title": "الإشعارات",
    "subtitle": "مركز تنبيهات Guardian 360",
    "summary": {
      "unread_one": "{count} إشعار غير مقروء",
      "unread_many": "{count} إشعار غير مقروء",
      "all_read": "كل الإشعارات مقروءة",
      "empty": "لا توجد إشعارات حالياً",
      "active_body": "تابع تنبيهات الوصول الآمن والطوارئ والنظام مع فصل واضح بين أنواعها.",
      "empty_body": "ستظهر هنا تنبيهات الوصول الآمن، بلاغات الطوارئ، تنبيهات البطارية، والمزامنة المهمة فور وصولها.",
      "total_chip": "{count} إجمالي",
      "unread_chip": "{count} غير مقروء",
      "synced": "محدّث"
    },
    "actions": {
      "read_all": "قراءة الكل",
      "retry": "إعادة المحاولة",
      "cancel": "إلغاء",
      "delete": "حذف",
      "done": "تم"
    },
    "fallback_title": "إشعار جديد",
    "empty": {
      "title": "لا توجد إشعارات",
      "body": "ستظهر هنا تنبيهات الوصول الآمن، البلاغات المرسلة، تنبيهات البطارية، والمزامنة المهمة من Guardian 360."
    },
    "filtered_empty": {
      "title": "لا توجد نتائج في هذا التصنيف",
      "body": "اختر تصنيفاً آخر أو اسحب للأسفل لتحديث القائمة."
    },
    "error": {
      "title": "تعذر تحميل الإشعارات",
      "body": "تحقق من اتصال الإنترنت أو صلاحيات الوصول إلى البيانات ثم أعد المحاولة."
    },
    "dates": {
      "today": "اليوم",
      "yesterday": "أمس"
    },
    "relative": {
      "just_now": "الآن",
      "minutes_ago": "منذ {count} دقيقة",
      "hours_ago": "منذ {count} ساعة",
      "days_ago_one": "منذ {count} يوم",
      "days_ago_many": "منذ {count} يوم"
    },
    "filters": {
      "all": "الكل",
      "unread": "غير المقروء",
      "safe_arrival": "الوصول الآمن",
      "emergency": "الطوارئ",
      "kroka": "الكروكة",
      "system": "النظام"
    },
    "priority": {
      "critical": "حرج",
      "high": "مهم",
      "low": "منخفض"
    },
    "types": {
      "sync": "مزامنة",
      "battery": "بطارية",
      "accident_alert": "تنبيه حادث",
      "emergency": "بلاغ طوارئ",
      "system": "النظام",
      "status_update": "تحديث حالة",
      "safe_arrival_started": "بدء الوصول الآمن",
      "safe_arrival_paused": "إيقاف الوصول الآمن مؤقتاً",
      "safe_arrival_resumed": "استئناف الرحلة",
      "safe_arrival_near_destination": "قريب من الوجهة",
      "safe_arrival_arrived": "وصل بأمان",
      "safe_arrival_cancelled": "إلغاء الوصول الآمن",
      "safe_arrival_danger": "تنبيه خطر في الوصول الآمن",
      "safe_arrival": "الوصول الآمن",
      "kroka_report_saved": "تقرير كروكة",
      "notification": "إشعار"
    },
    "delete_dialog": {
      "title": "حذف الإشعار؟",
      "body": "سيتم حذف هذا الإشعار من مركز الإشعارات فقط، ولن يؤثر على البلاغات الرسمية أو رحلات الوصول الآمن."
    },
    "details": {
      "title": "تفاصيل الإشعار",
      "linked_accident": "مرتبط ببلاغ طوارئ محفوظ في قاعدة البيانات.",
      "linked_safe_arrival_destination": "مرتبط برحلة وصول آمن إلى {destination}.",
      "linked_safe_arrival_saved": "مرتبط برحلة وصول آمن محفوظة في قاعدة البيانات.",
      "linked_kroka_report_reference": "مرتبط بتقرير كروكة محفوظ داخل Guardian 360 بالرقم المرجعي: {reference}.",
      "linked_kroka_report_saved": "مرتبط بتقرير كروكة محفوظ داخل Guardian 360."
    }
  },
  "medical": {
    "title": "السجل الطبي للطوارئ",
    "actions": {
      "close": "إغلاق",
      "unlock_record": "فتح السجل",
      "use_device_auth": "استخدام تحقق الجهاز",
      "save_record": "حفظ",
      "saving": "جاري الحفظ...",
      "encrypt_and_save": "حفظ آمن"
    },
    "locked": {
      "title": "السجل مقفل أمنياً",
      "body": "هذه بيانات حساسة مخصصة لحالات الإنقاذ. سيُطلب تحقق الجهاز حسب إعدادات الأمان لديك."
    },
    "sections": {
      "basic": {
        "title": "المعلومات الأساسية",
        "subtitle": "ضرورية للإنقاذ والتعامل الأولي"
      },
      "vitals": {
        "title": "البيانات الحيوية",
        "subtitle": "معلومات مهمة للإنقاذ والتعامل الطبي"
      },
      "critical": {
        "title": "المعلومات الطبية الحرجة",
        "subtitle": "تساعد فرق الإنقاذ في التعامل مع الحالات الخاصة بسرعة وكفاءة"
      }
    },
    "fields": {
      "full_name": {
        "label": "الاسم الكامل",
        "hint": "أدخل الاسم كما يظهر في الهوية",
        "helper": ""
      },
      "national_id": {
        "label": "الرقم الوطني",
        "hint": "أدخل الرقم كما يظهر في الهوية",
        "helper": ""
      },
      "age": {
        "label": "العمر",
        "hint": "أدخل العمر الحالي أو اختر تاريخ الميلاد لحسابه تلقائياً",
        "auto_hint": "محسوب تلقائياً",
        "helper": "",
        "auto_helper": ""
      },
      "address": {
        "label": "العنوان",
        "hint": "أدخل مكان السكن الحالي أو العنوان الدائم",
        "helper": ""
      },
      "weight": {
        "label": "الوزن",
        "hint": "وزن الجسم بالكيلوغرامات",
        "helper": "",
        "suffix": "كغم"
      },
      "height": {
        "label": "الطول",
        "hint": "طول الجسم بالسنتيمترات",
        "helper": "",
        "suffix": "سم"
      },
      "gender": {
        "label": "الجنس",
        "male": "ذكر",
        "female": "أنثى",
        "helper": ""
      },
      "allergies": {
        "label": "الحساسية",
        "hint": "اذكر الحساسية المعروفة أو اكتب: لا يوجد",
        "helper": ""
      },
      "medications": {
        "label": "الأدوية المستمرة",
        "hint": "اذكر الأدوية المستخدمة بانتظام أو اكتب: لا يوجد",
        "helper": ""
      },
      "chronic_diseases": {
        "label": "الأمراض المزمنة",
        "hint": "اذكر الأمراض المزمنة أو اكتب: لا يوجد",
        "helper": ""
      },
      "notes": {
        "label": "ملاحظات إضافية",
        "hint": "أدخل أي معلومات طبية إضافية قد تساعد فرق الإنقاذ في التعامل مع الحالة.",
        "helper": ""
      },
      "date_of_birth": {
        "label": "تاريخ الميلاد",
        "hint": "اختر تاريخ الميلاد",
        "helper": "",
        "clear": "مسح"
      },
      "blood_type": {
        "label": "فصيلة الدم",
        "hint": "اختر فصيلة الدم الصحيحة",
        "helper": "",
        "sheet_title": "حدد فصيلة الدم",
        "sheet_subtitle": "اختر فصيلة الدم الصحيحة من القائمة"
      },
      "organ_donor": {
        "label": "متبرع بالأعضاء",
        "helper": ""
      }
    },
    "date_picker": {
      "help": "اختر تاريخ الميلاد"
    },
    "security": {
      "banner": "السجل الطبي محمي بمعايير أمان عالية. يمكن للجهات المصرح لها الوصول إليه في حالات الطوارئ فقط.",
      "unlocking": "جاري فتح السجل الطبي باستخدام {method}...",
      "unlock_success": "تم فتح السجل الطبي بنجاح",
      "unlock_failed": "تعذر فتح السجل الطبي. تحقق من إعدادات الأمان أو جرّب طريقة تحقق أخرى."
    },
    "completion": {
      "ready_title": "جاهز للطوارئ",
      "required_title": "استكمال البيانات مطلوب",
      "ready_body": "الحقول الأساسية مكتملة",
      "required_body": "أكمل الحقول الحرجة لتفعيل حماية الطوارئ"
    },
    "messages": {
      "save_success": "تم الحفظ بنجاح"
    },
    "validation": {
      "full_name_invalid": "الاسم غير صحيح",
      "national_id_invalid": "يجب أن يكون {length} أرقام",
      "blood_type_required": "اختر فصيلة الدم الصحيحة",
      "age_invalid": "العمر غير منطقي",
      "birth_date_invalid": "تاريخ الميلاد غير منطقي",
      "weight_invalid": "القيمة غير واقعية",
      "height_invalid": "القيمة غير واقعية",
      "address_invalid": "العنوان غير صحيح",
      "allergies_required": "املأ الحساسية أو اكتب: لا يوجد",
      "allergies_invalid": "القيمة غير صحيحة",
      "medications_required": "املأ الأدوية أو اكتب: لا يوجد",
      "medications_invalid": "القيمة غير صحيحة",
      "chronic_diseases_required": "املأ الأمراض أو اكتب: لا يوجد",
      "chronic_diseases_invalid": "القيمة غير صحيحة",
      "notes_invalid": "الملاحظات طويلة جداً",
      "gender_required": "اختر الجنس"
    },
    "errors": {
      "save_failed": "فشل الحفظ",
      "init_failed": "فشل التهيئة",
      "auth_failed": "فشل التحقق",
      "load_failed": "فشل التحميل",
      "user_not_signed_in": "المستخدم غير مسجل",
      "cloud_update_failed_local_saved": "تم الحفظ محلياً، وتعذر حفظ النسخة السحابية",
      "save_exception": "خطأ أثناء الحفظ"
    }
  },
  "safe_arrival": {
    "title": "الوصول الآمن",
    "setup_info": "حدد وجهتك والوقت المتوقع للوصول. إذا لم تؤكد وصولك في الوقت المحدد، سيقوم النظام بتفعيل تنبيه الطوارئ وإبلاغ جهات الاتصال الطارئة.",
    "destination_label": "إلى أين تتجه؟",
    "destination_hint": "أدخل العنوان أو المكان الذي تتجه إليه",
    "duration_label": "الوقت المتوقع للوصول (بالدقائق)",
    "duration_hint": "الوقت التقريبي للوصول إلى الوجهة",
    "btn_start_tracking": "بدء تتبع الرحلة الآمنة",
    "heading_to": "متوجه إلى:",
    "time_remaining": "الوقت المتبقي للوصول",
    "btn_cancel_trip": "إلغاء الرحلة",
    "btn_confirm_arrival": "تأكيد الوصول بسلام",
    "arrived_title": "تم تأكيد الوصول بأمان",
    "arrived_subtitle": "تم الوصول إلى {destination} بنجاح",
    "route_start": "نقطة الانطلاق",
    "route_end": "الوجهة",
    "stat_time": "الوقت المستغرق",
    "stat_distance": "المسافة المقطوعة",
    "stat_rating": "تقييم الأمان",
    "ai_report_title": "تقرير Guardian AI",
    "ai_report_text": "تقرير ذكي عن رحلتك إلى {destination}، يشمل تحليل المسار، السرعة، والتوقفات لمساعدتك على فهم ظروف الرحلة بشكل أفضل.",
    "btn_notify_family": "طمأنة جهات الاتصال عبر WhatsApp",
    "danger_title": "انتهى وقت الرحلة المحدد",
    "danger_subtitle": "لم يتم تأكيد الوصول في الوقت المحدد.\nتم تفعيل بروتوكول الطوارئ وإبلاغ جهات الاتصال الطارئة.",
    "btn_im_safe": "إلغاء التنبيه، أنا بخير"
  },
  "kroka": {
    "title": "الكروكة الذكية",
    "subtitle": "تقرير حادث مروري ذكي داخل Guardian 360",
    "location_fetching": "جاري تحديد موقع الحادث...",
    "location_confirmed": "تم التقاط موقع الحادث ({location})",
    "section_damage": "حدد مكان الضرر في مركبتك بدقة",
    "damage_front": "أمام",
    "damage_back": "خلف",
    "damage_left": "يسار",
    "damage_right": "يمين",
    "section_fault": "تقدير المسؤولية",
    "fault_me": "أنا",
    "fault_other": "الطرف الآخر",
    "fault_unknown": "غير متأكد",
    "section_vehicles": "بيانات المركبات المشاركة في الحادث",
    "vehicle_mine": "مركبتي",
    "vehicle_other": "المركبة الأخرى",
    "plate_number": "الرقم",
    "plate_code": "الترميز",
    "section_evidence": "أدلة التقرير",
    "evidence_encrypted": "أدلة محفوظة ضمن التقرير",
    "btn_camera": "إضافة صور الضرر",
    "btn_camera_done": "تمت إضافة الصورة",
    "camera_opening": "توثيق الأدلة غير مفعّل حالياً.",
    "btn_voice": "إضافة تسجيل صوتي",
    "notes_hint": "أدخل وصفاً مختصراً لظروف الحادث وحالة الأطراف، دون مبالغة أو أحكام.",
    "btn_submit": "إنشاء تقرير الحادث الذكي",
    "error_validation": "يرجى استكمال البيانات الأساسية للتقرير.",
    "success_title": "تم حفظ تقرير الحادث",
    "success_subtitle": "تم إنشاء تقرير داخلي داخل Guardian 360 برقم مرجعي للمراجعة أو المشاركة عند الحاجة.",
    "btn_back_home": "العودة للرئيسية",
    "location": {
      "title": "موقع الحادث",
      "fetching": "جاري تحديد الموقع...",
      "ready": "تم التقاط الموقع",
      "unavailable": "الموقع غير متاح",
      "waiting_body": "يحتاج التقرير إلى موقع حقيقي من الجهاز قبل الحفظ.",
      "accuracy_value": "الدقة {meters} م"
    },
    "damage": {
      "title": "تحديد مكان الضرر",
      "subtitle": "اختر أقرب منطقة للضرر على المركبة للمساعدة في إنشاء تقرير أدق للمراجعة والتأمين.",
      "front": "أمام",
      "front_left": "أمام يسار",
      "front_right": "أمام يمين",
      "left": "يسار",
      "left_front_door": "باب يسار أمامي",
      "left_rear_door": "باب يسار خلفي",
      "right": "يمين",
      "right_front_door": "باب يمين أمامي",
      "right_rear_door": "باب يمين خلفي",
      "rear_left": "خلف يسار",
      "rear_right": "خلف يمين",
      "back": "خلف",
      "not_selected": "غير محدد",
      "selected_value": "المحدد حالياً: {value}"
    },
    "fault": {
      "title": "تقدير المسؤولية",
      "helper": "هذا تقدير من المستخدم للمساعدة في تنظيم التقرير ولا يعد قراراً رسمياً.",
      "me": "أنا",
      "other": "الطرف الآخر",
      "unknown": "غير متأكد"
    },
    "vehicles": {
      "title": "بيانات المركبات",
      "helper": "أدخل الترميز ورقم اللوحة كما يظهران على لوحة المركبة الأردنية.",
      "mine": "مركبتي",
      "other": "المركبة الأخرى",
      "required": "مطلوب",
      "optional": "اختياري",
      "plate_country": "JORDAN",
      "plate_number": "الرقم",
      "plate_code": "الترميز",
      "scan_plate": "مسح اللوحة بالذكاء الاصطناعي",
      "scanning_plate": "جاري قراءة اللوحة...",
      "ocr_filled": "معبأة تلقائياً",
      "scan_helper": "صوّر اللوحة بوضوح أو اختر صورة قريبة للوحة المركبة.",
      "ocr_camera_filled": "قراءة مباشرة بالكاميرا",
      "ocr_gallery_filled": "قراءة من المعرض",
      "ocr_edited_filled": "تم تعديل قراءة OCR",
      "scan_source_title": "مصدر صورة اللوحة",
      "scan_source_subtitle": "اختر التصوير المباشر لتوثيق أقوى، أو اختر صورة واضحة من المعرض.",
      "scan_from_camera": "تصوير مباشر بالكاميرا",
      "scan_from_camera_hint": "الأفضل للتأمين والشرطة لأنه يثبت وقت الالتقاط أثناء البلاغ.",
      "scan_from_gallery": "اختيار صورة من المعرض",
      "scan_from_gallery_hint": "استخدم صورة قريبة وواضحة للوحة المركبة."
    },
    "details": {
      "title": "تفاصيل إضافية",
      "helper": "اكتب وصفاً مختصراً يساعد في فهم ظروف الحادث دون مبالغة أو أحكام.",
      "notes_hint": "أدخل وصفاً مختصراً لظروف الحادث واتجاه الحركة وحالة الأطراف، دون مبالغة أو أحكام."
    },
    "signals": {
      "title": "مؤشرات التقرير",
      "subtitle": "بيانات مساعدة للمراجعة تشمل دقة الموقع والسرعة المتاحة من GPS عند الالتقاط.",
      "accuracy": "دقة الموقع",
      "speed": "سرعة الجهاز",
      "unavailable": "غير متاح",
      "speed_value": "{speed} كم/س",
      "neutral_note": "هذه المؤشرات لا تثبت المسؤولية ولا تصدر حكماً على الحادث، لكنها تساعد في مراجعة التقرير عند الحاجة."
    },
    "review": {
      "title": "مراجعة قبل الحفظ",
      "subtitle": "راجع البيانات الأساسية قبل إنشاء التقرير.",
      "damage": "مكان الضرر",
      "fault": "تقدير المسؤولية",
      "my_plate": "لوحة مركبتي",
      "other_plate": "لوحة الطرف الآخر",
      "location": "الموقع",
      "not_ready": "غير مكتمل",
      "optional_empty": "غير مدخل",
      "evidence": "الأدلة",
      "evidence_empty": "لم تتم إضافة أدلة",
      "evidence_count": "{count} دليل مرفق",
      "driver_license": "رخصة القيادة"
    },
    "evidence": {
      "title": "أدلة الحادث",
      "count": "{count} دليل مرفق",
      "ready_to_capture": "جاهز لإضافة أدلة الحادث",
      "ready_description": "يمكنك رفع صور أو فيديو أو صوت أو شهادات شهود وربطها بتقرير الحادث.",
      "uploaded_description": "تم ربط الأدلة بتقرير الحادث وسيتم حفظها مع بيانات البلاغ.",
      "capture_not_enabled": "توثيق الأدلة غير مفعّل حالياً",
      "draft_ready": "ملف التقرير جاهز لاستقبال الأدلة",
      "description": "يمكن ربط الصور والفيديو والتسجيلات الصوتية وشهادات الشهود بتقرير الحادث عند تفعيل التوثيق.",
      "draft_description": "تم تجهيز ملف تقرير آمن داخل Guardian 360، وسيتم ربط أي أدلة مستقبلية بهذا التقرير.",
      "capture_pending_note": "التقاط الأدلة سيُفعّل في المرحلة التالية بعد ربط الكاميرا ورفع الملفات.",
      "types": {
        "images": "صور",
        "videos": "فيديو",
        "audio": "صوت",
        "witnesses": "شهود",
        "files": "ملف"
      },
      "actions": {
        "add": "إضافة دليل",
        "uploading": "جاري رفع الدليل...",
        "disabled": "إضافة الأدلة غير مفعّلة",
        "prepare": "تجهيز ملف التقرير",
        "preparing": "جاري التجهيز...",
        "ready": "ملف التقرير جاهز",
        "camera": "تصوير مباشر",
        "camera_hint": "افتح الكاميرا لتوثيق دليل لحظي مرتبط بالحادث.",
        "gallery": "اختيار من المعرض",
        "gallery_hint": "اختر صورة أو فيديو محفوظ إذا كان متاحاً.",
        "files": "إضافة ملف دليل",
        "files_hint": "اختر صورة أو فيديو أو تسجيل صوتي من الجهاز.",
        "add_to_report": "إضافة دليل للتقرير",
        "select_first": "اختر دليلاً أولاً",
        "clear_selection": "إزالة الاختيار"
      },
      "audit_hint": "يتم ربط كل دليل بوقت الالتقاط ومصدره وموقع الحادث والسرعة المتاحة لدعم المراجعة وتقليل التلاعب.",
      "source_title": "إضافة دليل للحادث",
      "source_subtitle": "اختر طريقة توثيق الدليل. التصوير المباشر يعطي قوة أعلى للتقرير.",
      "video_source_title": "إضافة فيديو للحادث",
      "video_source_subtitle": "يمكنك تصوير فيديو مباشر أو اختيار فيديو محفوظ لدعم تقرير الحادث.",
      "witness": {
        "title": "إضافة شهادة شاهد",
        "name": "اسم الشاهد (اختياري)",
        "phone": "رقم الهاتف (اختياري)",
        "statement": "الشهادة أو الملاحظة"
      },
      "pending_title": "دليل جاهز للإضافة",
      "pending_description": "راجع الدليل المختار ثم اضغط إضافة دليل لربطه بتقرير الحادث.",
      "sources": {
        "camera": "تصوير مباشر",
        "gallery": "من المعرض",
        "file": "ملف من الجهاز",
        "unknown": "مصدر غير محدد"
      }
    },
    "actions": {
      "submit": "إنشاء تقرير الحادث الذكي",
      "submitting": "جاري إنشاء التقرير...",
      "refresh_location": "تحديث الموقع",
      "retry_location": "إعادة المحاولة",
      "open_settings": "إعدادات الموقع",
      "back_home": "العودة للرئيسية",
      "preparing_report": "جاري تجهيز ملف التقرير...",
      "generating_pdf": "جاري تجهيز ملف PDF..."
    },
    "success": {
      "title": "تم حفظ تقرير الحادث",
      "subtitle": "تم إنشاء تقرير داخلي داخل Guardian 360 برقم مرجعي. يمكنك استخدامه للمراجعة أو المشاركة عند الحاجة.",
      "reference_label": "الرقم المرجعي داخل Guardian 360",
      "location_label": "الموقع المسجل"
    },
    "errors": {
      "invalid_damage_point": "اختيار مكان الضرر غير صحيح.",
      "invalid_fault_status": "اختيار تقدير المسؤولية غير صحيح.",
      "location_unavailable": "تعذر تحديد موقع حقيقي من الجهاز. تحقق من تفعيل GPS والصلاحيات.",
      "location_required": "يجب توفر موقع حقيقي قبل حفظ تقرير الكروكة.",
      "user_not_signed_in": "يجب تسجيل الدخول قبل إنشاء التقرير.",
      "damage_required": "يرجى تحديد مكان الضرر في المركبة.",
      "fault_required": "يرجى اختيار تقدير المسؤولية.",
      "plate_required": "يرجى إدخال الترميز ورقم اللوحة.",
      "plate_digits_only": "الترميز ورقم اللوحة يجب أن يحتويان على أرقام فقط.",
      "invalid_plate_code": "ترميز اللوحة يجب أن يكون رقماً من 0 إلى 99.",
      "invalid_plate_number": "رقم اللوحة يجب أن يكون رقماً من 1 إلى 99999.",
      "invalid_vehicle_plate": "بيانات اللوحة غير صحيحة.",
      "duplicate_vehicle_plate": "لا يمكن أن تكون لوحة المركبة الأخرى مطابقة للوحة مركبتك.",
      "notes_too_long": "الملاحظات طويلة جداً. الحد الأقصى 500 حرف.",
      "submit_failed": "تعذر حفظ تقرير الكروكة. تحقق من الاتصال وصلاحيات Firebase.",
      "evidence_capture_not_configured": "إضافة أدلة الحادث غير مفعّلة حالياً.",
      "invalid_evidence": "بيانات الدليل غير صحيحة.",
      "evidence_not_found": "لم يتم العثور على الدليل المطلوب.",
      "report_not_submitted": "يجب حفظ تقرير الحادث قبل تحديث الأدلة.",
      "evidence_update_failed": "تعذر تحديث أدلة التقرير. تحقق من الاتصال ثم أعد المحاولة.",
      "not_allowed": "ليست لديك صلاحية لتنفيذ هذا الإجراء.",
      "draft_create_failed": "تعذر تجهيز ملف التقرير. تحقق من الاتصال ثم حاول مرة أخرى.",
      "draft_discard_failed": "تعذر إلغاء مسودة التقرير.",
      "draft_operation_failed": "تعذر تنفيذ عملية المسودة.",
      "draft_not_found": "لم يتم العثور على مسودة التقرير.",
      "draft_not_editable": "لا يمكن تعديل هذه المسودة حالياً.",
      "plate_ocr_failed": "تعذر قراءة اللوحة من الصورة. حاول بصورة أوضح.",
      "plate_ocr_unsupported_platform": "مسح اللوحة مدعوم حالياً على Android و iOS فقط.",
      "plate_ocr_invalid_image": "تعذر استخدام صورة اللوحة المحددة. اختر صورة واضحة بصيغة مدعومة.",
      "plate_ocr_no_text": "لم يتم العثور على نص واضح داخل الصورة.",
      "plate_ocr_no_plate": "تم قراءة الصورة لكن لم يتم استخراج رقم لوحة أردنية صالح.",
      "license_scan_failed": "تعذر قراءة رخصة القيادة. جرّب صورة أوضح.",
      "license_scan_required": "يجب تصوير الرخصة أو اختيارها أولاً قبل الاعتماد.",
      "license_scan_invalid_image": "صورة الرخصة غير صالحة أو غير واضحة.",
      "license_scan_no_text": "لم يتم العثور على نص واضح داخل صورة الرخصة.",
      "license_scan_no_data": "تمت قراءة الصورة لكن لم يتم استخراج بيانات رخصة كافية.",
      "license_scan_unsupported_platform": "قراءة الرخصة مدعومة حالياً على أجهزة Android و iOS فقط.",
      "pdf_generation_failed": "تم حفظ التقرير، لكن تعذر تجهيز ملف PDF حالياً. تحقق من الاتصال ثم حاول لاحقاً.",
      "evidence_selection_required": "اختر دليلاً قبل الإضافة إلى التقرير."
    },
    "license": {
      "title": "توثيق رخصة القيادة",
      "helper": "يربط التقرير ببيانات السائق صاحب البلاغ ويدعم مراجعة الشرطة والتأمين دون أن يكون حكماً قانونياً.",
      "my_driver": "رخصتي",
      "recommended": "يرفع الموثوقية",
      "scan_camera": "تصوير الرخصة",
      "scan_gallery": "اختيار من المعرض",
      "confirm": "اعتماد البيانات",
      "skip": "ليس الآن",
      "source": {
        "camera": "تصوير مباشر",
        "gallery": "من المعرض",
        "edited": "معدلة بعد القراءة"
      },
      "status": {
        "not_provided": "غير موثقة",
        "verified": "موثقة",
        "pending_review": "بانتظار الاعتماد",
        "skipped": "غير موثقة",
        "refused": "غير موثقة"
      },
      "fields": {
        "driver_name": "اسم السائق",
        "national_id": "رقم الهوية",
        "license_number": "رقم الرخصة",
        "license_class": "فئة الرخصة",
        "expiry_date": "تاريخ الانتهاء"
      },
      "messages": {
        "scan_success": "تم استخراج بيانات الرخصة بنجاح. يرجى مراجعتها قبل الاعتماد.",
        "scan_failed": "تعذر قراءة بيانات الرخصة بوضوح. يمكنك المحاولة بصورة أوضح.",
        "skipped": "تم تخطي توثيق الرخصة حالياً.",
        "refused": "تم تسجيل رفض الطرف الآخر لتوثيق الرخصة."
      },
      "compact_hint": "",
      "sheet_title": "توثيق رخصة القيادة",
      "sheet_subtitle": "صوّر رخصتك أو اختر صورة واضحة لاستخراج البيانات وربطها بتقرير الحادث.",
      "summary_verified": "تم ربط بيانات الرخصة بالتقرير.",
      "summary_pending": "تمت القراءة، بانتظار اعتماد البيانات.",
      "scan_camera_hint": "افتح الكاميرا والتقط صورة واضحة للرخصة.",
      "scan_gallery_hint": "اختر صورة واضحة محفوظة على الجهاز.",
      "confirm_hint": "اعتماد البيانات المستخرجة وربطها بالتقرير."
    },
    "report": {
      "pdf_status": "تقرير PDF",
      "generating": "جاري توليد التقرير الرسمي...",
      "pdf_pending": "تم حفظ البلاغ، لكن ملف PDF لم يجهز بعد. يمكنك إعادة المحاولة لاحقاً.",
      "pdf_ready": "تم تجهيز تقرير PDF الرسمي",
      "pdf_ready_description": "تم توليد تقرير الكروكة الذكية ورفعه بشكل آمن، ويحتوي على بيانات الحادث والأدلة والرخص والمؤشرات المهمة.",
      "open_pdf": "فتح التقرير"
    }
  },
  "signup": {
    "title": "إنشاء حساب جديد",
    "subtitle": "أنشئ حسابك لتفعيل خدمات الحماية والطوارئ",
    "full_name": "الاسم الكامل",
    "phone": "رقم الهاتف",
    "email": "البريد الإلكتروني",
    "password": "كلمة المرور",
    "btn_create": "إنشاء الحساب",
    "have_account": "لديك حساب بالفعل؟",
    "login": "تسجيل الدخول",
    "password_note": "يجب أن تتكون كلمة المرور من 6 أحرف أو أرقام على الأقل",
    "hints": {
      "full_name": "أدخل اسمك الكامل",
      "phone": "أدخل رقم هاتفك",
      "email": "أدخل بريدك الإلكتروني",
      "password": "••••••••"
    },
    "success": {
      "account_ready": "تم تجهيز الحساب، جاري التحقق..."
    },
    "errors": {
      "required_fields": "يرجى تعبئة جميع الحقول",
      "invalid_name": "يرجى إدخال اسم حقيقي",
      "invalid_phone": "يرجى إدخال رقم هاتف صحيح",
      "invalid_email": "يرجى إدخال بريد إلكتروني صحيح",
      "weak_password": "كلمة المرور ضعيفة",
      "email_in_use": "البريد الإلكتروني مستخدم بالفعل، حاول تسجيل الدخول أو استخدم بريد آخر",
      "profile_setup_failed": "تعذر إعداد السجل الطبي، يرجى المحاولة لاحقاً."
    }
  },
  "login": {
    "title": "تسجيل الدخول",
    "subtitle": "مرحباً بعودتك",
    "email": "البريد الإلكتروني",
    "password": "كلمة المرور",
    "btn_login": "تسجيل الدخول",
    "forgot_password": "نسيت كلمة المرور؟",
    "forgot_password_title": "نسيت كلمة المرور",
    "forgot_password_desc": "أدخل بريدك الإلكتروني لاستلام رابط إعادة تعيين كلمة المرور",
    "btn_send_link": "إرسال الرابط",
    "success_reset_link": "تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني",
    "no_account": "ليس لديك حساب؟",
    "signup": "إنشاء حساب",
    "hints": {
      "email": "أدخل بريدك الإلكتروني",
      "password": "••••••••"
    },
    "errors": {
      "required_fields": "يرجى تعبئة البريد الإلكتروني وكلمة المرور",
      "invalid_credentials": "البريد الإلكتروني أو كلمة المرور غير صحيحة",
      "too_many_attempts": "تم حظر الدخول مؤقتاً لكثرة المحاولات الخاطئة",
      "google_failed": "تعذر تسجيل الدخول بواسطة Google. تحقق من الاتصال بالإنترنت."
    }
  },
  "profile": {
    "title": "الملف الشخصي",
    "edit": "تعديل الملف الشخصي",
    "name": "الاسم",
    "email": "البريد الإلكتروني",
    "phone": "رقم الهاتف",
    "logout": "تسجيل الخروج"
  },
  "settings": {
    "title": "الإعدادات",
    "logout": "تسجيل الخروج",
    "sections": {
      "account": "الحساب والأمان",
      "safety": "الطوارئ والسلامة",
      "detection": "الكشف والحساسية",
      "devices": "الأجهزة المتصلة",
      "app": "إعدادات التطبيق",
      "help": "المساعدة والدعم"
    },
    "overview": {
      "title": "مركز التحكم",
      "subtitle": "تحكم بخيارات السلامة، كشف الحوادث، الأجهزة المتصلة، اللغة، والتنبيهات من مكان واحد.",
      "live_location": "الموقع",
      "live_location_on": "مفعّل",
      "live_location_off": "متوقف",
      "battery": "البطارية",
      "battery_on": "مراقبة",
      "battery_off": "متوقفة",
      "sensitivity": "الحساسية"
    },
    "account": {
      "profile_title": "الملف الشخصي والأمان",
      "profile_subtitle": "عرض بيانات الحساب وحالة تسجيل الدخول",
      "default_user_name": "مستخدم Guardian",
      "email_unavailable": "البريد الإلكتروني غير متاح",
      "signed_in": "حساب موثق",
      "guest_session": "جلسة غير مسجلة",
      "password_title": "إعادة تعيين كلمة المرور",
      "password_subtitle": "إرسال رابط آمن إلى بريد الحساب"
    },
    "password_reset": {
      "title": "إعادة تعيين كلمة المرور",
      "message": "سيتم إرسال رابط آمن لإعادة تعيين كلمة المرور إلى البريد التالي:\n{email}",
      "email_unavailable": "لا يوجد بريد إلكتروني مرتبط بالحساب الحالي.",
      "send": "إرسال الرابط",
      "sending": "جاري الإرسال...",
      "sent": "تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.",
      "failed": "تعذر إرسال رابط إعادة تعيين كلمة المرور. تحقق من الاتصال ثم حاول مرة أخرى."
    },
    "safety": {
      "location_title": "مشاركة الموقع المباشر",
      "location_subtitle": "مشاركة موقعك مع جهات الاتصال الطارئة عند الحاجة",
      "shake_title": "الهز للطوارئ",
      "shake_subtitle": "تفعيل تنبيه الطوارئ عند هز الجهاز",
      "battery_title": "تنبيه البطارية المنخفضة",
      "battery_subtitle": "إخطار جهات الاتصال عند انخفاض البطارية"
    },
    "detection": {
      "sensitivity_title": "حساسية كشف الحوادث",
      "sensitivity_low": "حساسية منخفضة",
      "sensitivity_medium": "حساسية متوسطة",
      "sensitivity_high": "حساسية عالية",
      "sensitivity_very_high": "حساسية عالية جداً",
      "sensitivity_note": "الحساسية الأعلى تكشف الصدمات الطفيفة لكنها قد تزيد احتمالية التنبيهات غير الدقيقة"
    },
    "devices": {
      "connection_title": "اتصال الأجهزة الذكية",
      "connection_subtitle": "ربط وإدارة الأجهزة الذكية المدعومة",
      "connected": "متصل",
      "disconnected": "غير متصل",
      "manage": "إدارة"
    },
    "app": {
      "voice_title": "التنبيهات الصوتية",
      "voice_subtitle": "تفعيل الإشعارات والتنبيهات الصوتية",
      "language_title": "اللغة",
      "language_subtitle": "اختيار لغة واجهة التطبيق"
    },
    "language": {
      "sheet_title": "اختيار اللغة",
      "arabic": "العربية",
      "english": "English"
    },
    "help": {
      "faq_title": "الأسئلة الشائعة",
      "faq_subtitle": "إرشادات استخدام إعدادات السلامة والطوارئ",
      "faq_body": "تساعدك شاشة الإعدادات على ضبط خيارات الطوارئ، مشاركة الموقع، تنبيه البطارية، حساسية كشف الحوادث، اللغة، والأجهزة المتصلة. بعد تغيير أي إعداد مرتبط بالسلامة، اختبر السلوك على جهاز حقيقي للتأكد من أن الصلاحيات والخدمات تعمل كما يجب.",
      "support_title": "الدعم الفني",
      "support_subtitle": "إرشادات المساعدة داخل النظام",
      "support_body": "للحصول على الدعم، استخدم قناة الدعم الرسمية المعتمدة لمشروع Guardian 360. لا تشارك بيانات طبية أو معلومات حساسة إلا مع جهة موثوقة ومصرح لها ضمن النظام.",
      "about_title": "عن Guardian 360",
      "about_subtitle": "معلومات حول نظام الحماية الذكي",
      "about_body": "Guardian 360 نظام أمان ذكي يجمع كشف الحوادث، تنبيهات الطوارئ، الوصول الآمن، تتبع الموقع، السجل الطبي، والتكامل مع لوحة التحكم لمساعدة المستخدمين في الحالات الحرجة."
    },
    "version": {
      "label": "الإصدار 1.0.0+1",
      "copyright": "© 2026 VitaLink System"
    },
    "logout_dialog": {
      "title": "تأكيد تسجيل الخروج",
      "message": "هل أنت متأكد من تسجيل الخروج من حسابك؟",
      "cancel": "إلغاء",
      "confirm": "تسجيل الخروج",
      "signing_out": "جاري تسجيل الخروج..."
    }
  },
  "contacts": {
    "title": "جهات الاتصال الطارئة",
    "add": "إضافة جهة اتصال",
    "edit": "تعديل جهة الاتصال",
    "delete": "حذف جهة الاتصال",
    "empty": "لا توجد جهات اتصال طارئة",
    "primary": "جهة الاتصال الأساسية",
    "backup": "جهة اتصال احتياطية"
  },
  "sos": {
    "title": "نظام الطوارئ",
    "countdown": "باقي ثوانٍ قبل إرسال بلاغ الطوارئ...",
    "triggered": "تم تفعيل نظام الطوارئ",
    "cancelled": "تم إلغاء الطوارئ بنجاح",
    "alert_sent": "تم إرسال بلاغ الطوارئ بنجاح",
    "are_you_ok": "هل أنت بخير؟",
    "btn_im_safe": "أنا بخير",
    "btn_need_help": "أحتاج مساعدة",
    "voice": {
      "opening_manual": "تم بدء العد التنازلي للطوارئ. يمكنك الإلغاء إذا كنت بأمان.",
      "opening_auto": "تم رصد احتمال وقوع حادث. يمكنك الإلغاء إذا كنت بأمان."
    }
  },
  "map": {
    "title": "الخريطة",
    "locating": "جاري البحث في المنطقة...",
    "safe_zone_active": "نطاق الأمان النشط (5 كم)",
    "current_location": "موقعك الحالي",
    "searching_places": "جاري البحث عن خدمات الطوارئ القريبة...",
    "no_places": "لا توجد مراكز طوارئ ضمن نطاق 5 كم",
    "fetching_location": "جاري تحديد موقعك الحالي بدقة...",
    "location_success": "تم تحديد الموقع بنجاح",
    "location_failed": "تعذر تحديد الموقع الحالي"
  },
  "ai": {
    "title": "المساعد الذكي",
    "welcome": "مرحباً، أنا مساعدك الذكي في Guardian 360",
    "listening": "جاري الاستماع...",
    "error": "تعذر الاتصال بالخوادم الآمنة. حاول مجدداً لاحقاً.",
    "emergency_detected": "⚠️ تنبيه أمني: تم رصد عبارة قد تشير إلى خطر. سيتم توجيهك إلى نظام الطوارئ SOS."
  },
  "errors": {
    "email_in_use": "هذا البريد الإلكتروني مستخدم مسبقاً.",
    "invalid_email": "صيغة البريد الإلكتروني غير صحيحة.",
    "weak_password": "كلمة المرور ضعيفة جداً.",
    "network_error": "لا يوجد اتصال بالإنترنت.",
    "unknown": "حدث خطأ غير متوقع. حاول مجدداً.",
    "permission_denied": "تم رفض الصلاحية",
    "location_disabled": "خدمات الموقع (GPS) معطلة على جهازك"
  }
};
static const Map<String,dynamic> _en = {
  "app_name": "Guardian 360",
  "common": {
    "cancel": "Cancel",
    "confirm": "Confirm",
    "save": "Save",
    "edit": "Edit",
    "delete": "Delete",
    "retry": "Retry",
    "loading": "Loading...",
    "success": "Operation completed successfully",
    "error": "An error occurred",
    "back": "Back"
  },
  "greetings": {
    "morning": "Good morning,",
    "afternoon": "Good afternoon,",
    "evening": "Good evening,",
    "night": "Good evening,"
  },
  "home": {
    "title": "Guardian 360",
    "status_safe": "System is safe and active",
    "status_ready": "System Ready",
    "status_initializing": "Initializing System",
    "status_subtitle_safe": "All sensors are working efficiently",
    "status_subtitle_ready": "You can enable protection and start your trip",
    "status_subtitle_initializing": "Checking smart modules...",
    "sos_button": "SOS",
    "sos_subtitle": "Tap for assistance",
    "card_kroka": "Smart Kroka",
    "card_contacts": "Contacts",
    "card_safe_arrival": "Safe Arrival"
  },
  "notifications": {
    "title": "Notifications",
    "subtitle": "Guardian 360 alert center",
    "summary": {
      "unread_one": "{count} unread notification",
      "unread_many": "{count} unread notifications",
      "all_read": "All notifications are read",
      "empty": "No notifications yet",
      "active_body": "Follow Safe Arrival, emergency, and system alerts in one organized center.",
      "empty_body": "Safe Arrival updates, emergency reports, battery alerts, and important sync updates will appear here automatically.",
      "total_chip": "{count} total",
      "unread_chip": "{count} unread",
      "synced": "Synced"
    },
    "actions": {
      "read_all": "Read all",
      "retry": "Retry",
      "cancel": "Cancel",
      "delete": "Delete",
      "done": "Done"
    },
    "fallback_title": "New notification",
    "empty": {
      "title": "No notifications",
      "body": "Safe Arrival updates, sent reports, battery alerts, and important Guardian 360 sync updates will appear here."
    },
    "filtered_empty": {
      "title": "No notifications in this filter",
      "body": "Try another filter or pull down to refresh."
    },
    "error": {
      "title": "Failed to load notifications",
      "body": "Check your connection or Firestore permissions, then try again."
    },
    "dates": {
      "today": "Today",
      "yesterday": "Yesterday"
    },
    "relative": {
      "just_now": "Just now",
      "minutes_ago": "{count} min ago",
      "hours_ago": "{count} hr ago",
      "days_ago_one": "{count} day ago",
      "days_ago_many": "{count} days ago"
    },
    "filters": {
      "all": "All",
      "unread": "Unread",
      "safe_arrival": "Safe Arrival",
      "emergency": "Emergency",
      "kroka": "Kroka",
      "system": "System"
    },
    "priority": {
      "critical": "Critical",
      "high": "High",
      "low": "Low"
    },
    "types": {
      "sync": "Sync",
      "battery": "Battery",
      "accident_alert": "Accident alert",
      "emergency": "Emergency",
      "system": "System",
      "status_update": "Status update",
      "safe_arrival_started": "Safe Arrival started",
      "safe_arrival_paused": "Paused",
      "safe_arrival_resumed": "Resumed",
      "safe_arrival_near_destination": "Near destination",
      "safe_arrival_arrived": "Arrived safely",
      "safe_arrival_cancelled": "Safe Arrival cancelled",
      "safe_arrival_danger": "Safe Arrival risk alert",
      "safe_arrival": "Safe Arrival",
      "kroka_report_saved": "Kroka report",
      "notification": "Notification"
    },
    "delete_dialog": {
      "title": "Delete notification?",
      "body": "This only removes it from the notification center and will not affect official reports or Safe Arrival trips."
    },
    "details": {
      "title": "Notification details",
      "linked_accident": "Linked to an official emergency report in the database.",
      "linked_safe_arrival_destination": "Linked to a Safe Arrival trip to {destination}.",
      "linked_safe_arrival_saved": "Linked to a saved Safe Arrival trip in the database.",
      "linked_kroka_report_reference": "Linked to a saved Kroka report in Guardian 360 with reference: {reference}.",
      "linked_kroka_report_saved": "Linked to a saved Kroka report in Guardian 360."
    }
  },
  "medical": {
    "title": "Emergency Medical Record",
    "actions": {
      "close": "Close",
      "unlock_record": "Unlock record",
      "use_device_auth": "Use authentication",
      "save_record": "Save",
      "saving": "Saving...",
      "encrypt_and_save": "Encrypt and save"
    },
    "locked": {
      "title": "Record securely locked",
      "body": "Sensitive data for rescue only. Device authentication will appear based on your settings."
    },
    "sections": {
      "basic": {
        "title": "Basic information",
        "subtitle": "Essential for identification and first response"
      },
      "vitals": {
        "title": "Vital information",
        "subtitle": "Important for rescue and initial medical handling"
      },
      "critical": {
        "title": "Critical medical information",
        "subtitle": "Helps responders handle special medical conditions quickly and safely"
      }
    },
    "fields": {
      "full_name": {
        "label": "Full name",
        "hint": "As shown on ID",
        "helper": ""
      },
      "national_id": {
        "label": "National ID",
        "hint": "Enter the national ID number",
        "helper": ""
      },
      "age": {
        "label": "Age",
        "hint": "Enter the current age or date of birth; the age can be calculated automatically",
        "auto_hint": "Calculated automatically",
        "helper": "",
        "auto_helper": ""
      },
      "address": {
        "label": "Address",
        "hint": "Enter the current residence or permanent address",
        "helper": ""
      },
      "weight": {
        "label": "Weight",
        "hint": "Enter body weight in kilograms",
        "helper": "",
        "suffix": "kg"
      },
      "height": {
        "label": "Height",
        "hint": "Enter body height in centimeters",
        "helper": "",
        "suffix": "cm"
      },
      "gender": {
        "label": "Gender",
        "male": "Male",
        "female": "Female",
        "helper": ""
      },
      "allergies": {
        "label": "Allergies",
        "hint": "List known allergies, or write: None",
        "helper": ""
      },
      "medications": {
        "label": "Current medications",
        "hint": "List regular medications, or write: None",
        "helper": ""
      },
      "chronic_diseases": {
        "label": "Chronic diseases",
        "hint": "List chronic diseases, or write: None",
        "helper": ""
      },
      "notes": {
        "label": "Additional notes",
        "hint": "Add any information that may help responders, such as special medical conditions or specific instructions.",
        "helper": ""
      },
      "date_of_birth": {
        "label": "Date of birth",
        "hint": "Select date of birth",
        "helper": "",
        "clear": "Clear"
      },
      "blood_type": {
        "label": "Blood type",
        "hint": "Select the correct blood type",
        "helper": "",
        "sheet_title": "Select blood type",
        "sheet_subtitle": "Choose the correct blood type from the list"
      },
      "organ_donor": {
        "label": "Organ donor",
        "helper": ""
      }
    },
    "date_picker": {
      "help": "Select date of birth"
    },
    "security": {
      "banner": "The emergency medical record is protected by high security standards. Only authorized responders should access it during emergencies.",
      "unlocking": "Unlocking the emergency medical record using {method}...",
      "unlock_success": "Emergency medical record unlocked successfully",
      "unlock_failed": "Failed to unlock the emergency medical record. Check device security settings or try another method."
    },
    "completion": {
      "ready_title": "Ready for emergencies",
      "required_title": "Critical information required",
      "ready_body": "Required fields are complete",
      "required_body": "Complete the critical fields to enable protection"
    },
    "messages": {
      "save_success": "Saved successfully"
    },
    "validation": {
      "full_name_invalid": "Name is invalid",
      "national_id_invalid": "Must be {length} digits",
      "blood_type_required": "Select a valid blood type",
      "age_invalid": "Age is unrealistic",
      "birth_date_invalid": "Date is unrealistic",
      "weight_invalid": "Value is unrealistic",
      "height_invalid": "Value is unrealistic",
      "address_invalid": "Address is invalid",
      "allergies_required": "Fill allergies or write: None",
      "allergies_invalid": "Value is invalid",
      "medications_required": "Fill medications or write: None",
      "medications_invalid": "Value is invalid",
      "chronic_diseases_required": "Fill diseases or write: None",
      "chronic_diseases_invalid": "Value is invalid",
      "notes_invalid": "Notes are too long",
      "gender_required": "Select gender"
    },
    "errors": {
      "save_failed": "Save failed",
      "init_failed": "Initialization failed",
      "auth_failed": "Authentication failed",
      "load_failed": "Load failed",
      "user_not_signed_in": "User not signed in",
      "cloud_update_failed_local_saved": "Saved locally, cloud update failed",
      "save_exception": "Error while saving"
    }
  },
  "safe_arrival": {
    "title": "Safe Arrival",
    "setup_info": "Set your destination and expected arrival time. If you do not confirm arrival on time, Guardian 360 will activate the alert and notify your emergency contacts automatically.",
    "destination_label": "Where are you heading?",
    "destination_hint": "Enter the address or place you are heading to",
    "duration_label": "Expected arrival time (in minutes)",
    "duration_hint": "Enter the estimated travel time to the destination",
    "btn_start_tracking": "Start secure trip tracking",
    "heading_to": "Heading to:",
    "time_remaining": "Time remaining to arrival",
    "btn_cancel_trip": "Cancel Trip",
    "btn_confirm_arrival": "Confirm Safe Arrival",
    "arrived_title": "You arrived safely!",
    "arrived_subtitle": "Successfully arrived at {destination}",
    "route_start": "Starting Point",
    "route_end": "Destination",
    "stat_time": "Time taken",
    "stat_distance": "Distance covered",
    "stat_rating": "Safety rating",
    "ai_report_title": "Guardian AI Report",
    "ai_report_text": "Smart trip report for {destination}, including route, speed, and stop analysis to help review the trip conditions.",
    "btn_notify_family": "Notify emergency contact (WhatsApp)",
    "danger_title": "Allowed trip time has expired",
    "danger_subtitle": "Arrival was not confirmed.\nEmergency protocol has been activated and emergency contacts have been notified.",
    "btn_im_safe": "Cancel Alert (I'm Safe)"
  },
  "kroka": {
    "title": "Smart Kroka",
    "subtitle": "Smart traffic accident report inside Guardian 360",
    "location_fetching": "Detecting accident location...",
    "location_confirmed": "Accident location captured ({location})",
    "section_damage": "Select the damage location on your vehicle accurately",
    "damage_front": "Front",
    "damage_back": "Back",
    "damage_left": "Left",
    "damage_right": "Right",
    "section_fault": "Liability estimate",
    "fault_me": "Me",
    "fault_other": "Other party",
    "fault_unknown": "Not sure",
    "section_vehicles": "Vehicle details involved in the accident",
    "vehicle_mine": "My vehicle",
    "vehicle_other": "Other vehicle",
    "plate_number": "Number",
    "plate_code": "Code",
    "section_evidence": "Report evidence",
    "evidence_encrypted": "Evidence saved with the report",
    "btn_camera": "Add damage photos",
    "btn_camera_done": "Photo added",
    "camera_opening": "Evidence documentation is not enabled yet.",
    "btn_voice": "Add voice recording",
    "notes_hint": "Enter a short factual description of the accident circumstances and the condition of the involved parties.",
    "btn_submit": "Create Smart Accident Report",
    "error_validation": "Please complete the required report details.",
    "success_title": "Accident report saved",
    "success_subtitle": "An internal Guardian 360 report has been created with a reference number for review or sharing when needed.",
    "btn_back_home": "Back to Home",
    "location": {
      "title": "Accident location",
      "fetching": "Detecting location...",
      "ready": "Location captured",
      "unavailable": "Location unavailable",
      "waiting_body": "A real device location is required before saving the report.",
      "accuracy_value": "{meters} m accuracy"
    },
    "damage": {
      "title": "Damage location",
      "subtitle": "Select the closest damaged vehicle area to help create a more accurate report for review and insurance.",
      "front": "Front",
      "front_left": "Front left",
      "front_right": "Front right",
      "left": "Left",
      "left_front_door": "Left front door",
      "left_rear_door": "Left rear door",
      "right": "Right",
      "right_front_door": "Right front door",
      "right_rear_door": "Right rear door",
      "rear_left": "Rear left",
      "rear_right": "Rear right",
      "back": "Back",
      "not_selected": "Not selected",
      "selected_value": "Currently selected: {value}"
    },
    "fault": {
      "title": "Liability estimate",
      "helper": "This user-provided estimate helps organize the report and is not an official decision.",
      "me": "Me",
      "other": "Other party",
      "unknown": "Not sure"
    },
    "vehicles": {
      "title": "Vehicle details",
      "helper": "Enter the plate code and number as shown on the Jordanian vehicle plate.",
      "mine": "My vehicle",
      "other": "Other vehicle",
      "required": "Required",
      "optional": "Optional",
      "plate_country": "JORDAN",
      "plate_number": "Number",
      "plate_code": "Code"
    },
    "details": {
      "title": "Additional details",
      "helper": "Write a short factual description that helps explain the accident without exaggeration or judgment.",
      "notes_hint": "Enter a short description of the accident circumstances, movement direction, and party condition without exaggeration or judgment."
    },
    "signals": {
      "title": "Report signals",
      "subtitle": "Review-supporting data including GPS accuracy and available GPS speed at capture time.",
      "accuracy": "GPS accuracy",
      "speed": "Device speed",
      "unavailable": "Unavailable",
      "speed_value": "{speed} km/h",
      "neutral_note": "These signals do not prove liability or judge the accident. They only help with report review when needed."
    },
    "review": {
      "title": "Review before saving",
      "subtitle": "Review the required information before creating the report.",
      "damage": "Damage location",
      "fault": "Liability estimate",
      "my_plate": "My plate",
      "other_plate": "Other party plate",
      "location": "Location",
      "not_ready": "Not ready",
      "optional_empty": "Not entered",
      "evidence": "Evidence",
      "evidence_empty": "No evidence attached",
      "evidence_count": "{count} evidence item(s) attached"
    },
    "evidence": {
      "title": "Accident Evidence",
      "count": "{count} evidence item attached",
      "ready_to_capture": "Ready to add accident evidence",
      "ready_description": "You can upload photos, videos, audio notes, or witness statements and attach them to the accident report.",
      "uploaded_description": "Evidence has been attached to the accident report and will be saved with the case data.",
      "capture_not_enabled": "Evidence documentation is not enabled yet",
      "draft_ready": "Report file is ready to receive evidence",
      "description": "Photos, videos, audio recordings, and witness statements can be attached to the accident report when documentation is enabled.",
      "draft_description": "A secure report file has been prepared inside Guardian 360, and any future evidence will be attached to this report.",
      "capture_pending_note": "Evidence capture will be enabled in the next phase after connecting camera and file upload.",
      "types": {
        "images": "Photos",
        "videos": "Video",
        "audio": "Audio",
        "witnesses": "Witnesses"
      },
      "actions": {
        "add": "Add evidence",
        "uploading": "Uploading evidence...",
        "disabled": "Adding evidence is disabled",
        "prepare": "Prepare report file",
        "preparing": "Preparing...",
        "ready": "Report file ready"
      }
    },
    "actions": {
      "submit": "Create Smart Accident Report",
      "submitting": "Creating report...",
      "preparing_report": "Preparing report file...",
      "refresh_location": "Refresh location",
      "retry_location": "Retry",
      "open_settings": "Location settings",
      "back_home": "Back to Home"
    },
    "success": {
      "title": "Accident report saved",
      "subtitle": "An internal Guardian 360 report has been created with a reference number. You can use it for review or sharing when needed.",
      "reference_label": "Guardian 360 internal reference",
      "location_label": "Recorded location"
    },
    "errors": {
      "invalid_damage_point": "Invalid damage location.",
      "invalid_fault_status": "Invalid liability estimate.",
      "location_unavailable": "Could not detect a real device location. Check GPS and permissions.",
      "location_required": "A real location is required before saving the Kroka report.",
      "user_not_signed_in": "You must be signed in before creating the report.",
      "damage_required": "Please select the damage location on the vehicle.",
      "fault_required": "Please choose a liability estimate.",
      "plate_required": "Please enter the plate code and number.",
      "plate_digits_only": "Plate code and number must contain digits only.",
      "invalid_plate_code": "Plate code must be a number from 0 to 99.",
      "invalid_plate_number": "Plate number must be a number from 1 to 99999.",
      "invalid_vehicle_plate": "Vehicle plate details are invalid.",
      "duplicate_vehicle_plate": "The other vehicle plate cannot match your vehicle plate.",
      "notes_too_long": "Notes are too long. Maximum length is 500 characters.",
      "submit_failed": "Could not save the Kroka report. Check connection and Firebase permissions.",
      "evidence_capture_not_configured": "Adding accident evidence is not enabled yet.",
      "invalid_evidence": "Evidence data is invalid.",
      "evidence_not_found": "The requested evidence item was not found.",
      "report_not_submitted": "Save the accident report before updating evidence.",
      "evidence_update_failed": "Could not update report evidence. Check your connection and try again.",
      "not_allowed": "You are not authorized to perform this action.",
      "draft_create_failed": "Could not prepare the report file. Check your connection and try again.",
      "draft_discard_failed": "Could not discard the report draft.",
      "draft_operation_failed": "Could not complete the draft operation.",
      "draft_not_found": "Report draft was not found.",
      "draft_not_editable": "This draft cannot be edited right now."
    }
  },
  "signup": {
    "title": "Create New Account",
    "subtitle": "Create your account to keep Guardian 360 ready for emergencies",
    "full_name": "Full name",
    "phone": "Phone number",
    "email": "Email address",
    "password": "Password",
    "btn_create": "Create Account",
    "have_account": "Already have an account?",
    "login": "Login",
    "password_note": "Password must be at least 6 characters",
    "hints": {
      "full_name": "Enter your full name",
      "phone": "Enter your phone number",
      "email": "Enter your email address",
      "password": "••••••••"
    },
    "success": {
      "account_ready": "Account created successfully! Verifying now..."
    },
    "errors": {
      "required_fields": "Please fill in all fields",
      "invalid_name": "Please enter a valid full name",
      "invalid_phone": "Please enter a valid phone number",
      "profile_setup_failed": "Failed to prepare the medical profile. Please try again later.",
      "invalid_email": "Please enter a valid email address",
      "weak_password": "Password is too weak",
      "email_in_use": "This email is already in use. Sign in or use another email address."
    }
  },
  "login": {
    "title": "Login",
    "subtitle": "Welcome back",
    "email": "Email Address",
    "password": "Password",
    "btn_login": "Login",
    "forgot_password": "Forgot password?",
    "no_account": "Don't have an account?",
    "signup": "Sign Up",
    "hints": {
      "email": "Enter your email address",
      "password": "••••••••"
    },
    "forgot_password_title": "Forgot password",
    "forgot_password_desc": "Enter your email address to receive a reset link",
    "btn_send_link": "Send link",
    "success_reset_link": "A password reset link has been sent to your email",
    "errors": {
      "required_fields": "Please enter your email address and password",
      "invalid_credentials": "Email or password is incorrect",
      "too_many_attempts": "Sign-in has been temporarily blocked due to too many failed attempts",
      "google_failed": "Could not sign in with Google. Check your connection and try again."
    }
  },
  "profile": {
    "title": "Profile",
    "edit": "Edit Profile",
    "name": "Name",
    "email": "Email",
    "phone": "Phone",
    "logout": "Logout"
  },
  "settings": {
    "title": "Settings",
    "logout": "Logout",
    "sections": {
      "account": "Account & Security",
      "safety": "Emergency & Safety",
      "detection": "Detection & Sensitivity",
      "devices": "Connected Devices",
      "app": "Application Settings"
    },
    "account": {
      "profile_title": "Verified Profile",
      "profile_subtitle": "Your account is verified and secure",
      "biometric_title": "Biometric Authentication",
      "biometric_subtitle": "Use fingerprint or face recognition",
      "password_title": "Change Password",
      "password_subtitle": "Update your account password"
    },
    "safety": {
      "location_title": "Live Location Sharing",
      "location_subtitle": "Share your location with emergency contacts",
      "shake_title": "Shake to SOS",
      "shake_subtitle": "Activate emergency by shaking device",
      "battery_title": "Low Battery Alert",
      "battery_subtitle": "Notify contacts when battery is low"
    },
    "detection": {
      "sensitivity_title": "Accident Detection Sensitivity",
      "sensitivity_low": "Low Sensitivity",
      "sensitivity_medium": "Medium Sensitivity",
      "sensitivity_high": "High Sensitivity",
      "sensitivity_very_high": "Very High Sensitivity",
      "sensitivity_note": "Higher sensitivity detects minor impacts but may trigger false alarms"
    },
    "devices": {
      "connection_title": "Smart Device Connection",
      "connection_subtitle": "Connect your IoT devices",
      "connected": "Connected",
      "manage": "Manage"
    },
    "app": {
      "voice_title": "Voice Feedback",
      "voice_subtitle": "Enable voice notifications and alerts",
      "language_title": "Language",
      "language_subtitle": "Change application language"
    },
    "logout_dialog": {
      "title": "Confirm Logout",
      "message": "Are you sure you want to logout from your account?",
      "cancel": "Cancel",
      "confirm": "Logout"
    }
  },
  "contacts": {
    "title": "Emergency Contacts",
    "add": "Add Contact",
    "edit": "Edit Contact",
    "delete": "Delete Contact",
    "empty": "No emergency contacts",
    "primary": "Primary Rescuer 🥇",
    "backup": "Backup Contact"
  },
  "sos": {
    "title": "Emergency System",
    "countdown": "Final seconds before sending alert...",
    "triggered": "Emergency system activated",
    "cancelled": "Emergency cancelled successfully",
    "alert_sent": "Emergency report sent successfully to rescue teams",
    "are_you_ok": "Are you okay?",
    "btn_im_safe": "I'm Safe",
    "btn_need_help": "I Need Help",
    "voice": {
      "opening_manual": "Emergency countdown started. You can cancel it if you are safe.",
      "opening_auto": "A possible accident was detected. You can cancel the alert if you are safe."
    }
  },
  "map": {
    "title": "Map",
    "current_location": "Your current location",
    "fetching_location": "Determining your current location accurately...",
    "location_success": "Location determined successfully",
    "location_failed": "Failed to determine current location",
    "locating": "Scanning the area...",
    "safe_zone_active": "Active safety radius (5 km)",
    "searching_places": "Searching for emergency services...",
    "no_places": "No emergency centers found within 5 km"
  },
  "ai": {
    "title": "AI Assistant",
    "welcome": "Hello! I'm your smart assistant in Guardian 360",
    "listening": "Listening...",
    "error": "Sorry, an error occurred while connecting to secure servers.",
    "emergency_detected": "⚠️ Security alert: A critical phrase was detected. Redirecting to the SOS emergency system now."
  },
  "errors": {
    "email_in_use": "This email is already in use.",
    "invalid_email": "Invalid email format.",
    "weak_password": "Password is too weak.",
    "network_error": "No internet connection.",
    "unknown": "An unexpected error occurred, please try again.",
    "permission_denied": "Permission denied",
    "location_disabled": "Location services (GPS) are disabled on your device"
  }
};
static const Map<String, Map<String,dynamic>> mapLocales = {"ar": _ar, "en": _en};
}
