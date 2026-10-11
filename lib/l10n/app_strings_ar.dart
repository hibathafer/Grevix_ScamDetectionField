import '../models/analysis_result.dart';
import 'app_strings.dart';

/// Arabic display strings.
///
/// Written as clear, simple Modern Standard Arabic that reads naturally for
/// Iraqi users — not a word-for-word translation of the English.
///
/// **Scope note:** this class only translates what the user *reads*. It does
/// not add any Arabic *detection* capability. Every rule still matches
/// English text only, which is why [detectionCoverageNote] is surfaced in the
/// UI.
class ArabicStrings extends AppStrings {
  const ArabicStrings();

  @override
  String get languageCode => 'ar';

  @override
  bool get isRtl => true;

  @override
  String get languageName => 'العربية';

  /// Arabic count agreement: singular / dual / paucal (3-10) / plural (11+).
  static String _count(
    int n,
    String one,
    String two,
    String few,
    String many,
  ) {
    if (n == 1) return one;
    if (n == 2) return two;
    if (n >= 3 && n <= 10) return '$n $few';
    return '$n $many';
  }

  /// Rule params store lists joined with `", "`; use the Arabic comma in
  /// Arabic prose.
  static String _list(String joined) => joined.split(', ').join('، ');

  // -------------------------------------------------------------------------
  // App chrome
  // -------------------------------------------------------------------------

  /// The product name is a proper noun, so it stays in Latin script in both
  /// languages (the same way app names are kept in Latin in Arabic apps).
  @override
  String get appTitle => 'Scam Detection Field';

  @override
  String get howItWorksTooltip => 'كيف يعمل';

  @override
  String get languageTooltip => 'اللغة';

  // -------------------------------------------------------------------------
  // Home screen
  // -------------------------------------------------------------------------

  @override
  String get heroTitle => 'لماذا أتشكك في هذا؟';

  @override
  String get heroBody =>
      'الصق رابطاً أو رسالة استلمتها. ستحصل على مستوى واضح للمخاطة، '
      'والأسباب الحقيقية وراءه، وخطوتك القادمة — بعبارات بسيطة.';

  @override
  String get tryLinkExample => 'جرّب رابطاً مشبوهاً';

  @override
  String get tryMessageExample => 'جرّب رسالة مشبوهة';

  @override
  String get tabLink => 'رابط';

  @override
  String get tabMessage => 'رسالة';

  @override
  String get linkFieldLabel => 'الرابط المشبوه';

  @override
  String get messageFieldLabel => 'الرسالة المشبوهة';

  @override
  String get linkFieldHint => 'الصق الرابط هنا، مثلاً\nhttp://...';

  @override
  String get messageFieldHint => 'الصق الرسالة كاملة هنا...';

  @override
  String get errorEmptyInput => 'الصق أو اكتب شيئاً أولاً ليتم تحليله.';

  @override
  String get errorInvalidUrl =>
      'رابط غير صالح — يرجى إدخال رابط موقع صحيح لتحليله.';

  @override
  String get errorUnexpected =>
      'حدث خطأ غير متوقّع أثناء التحليل. لم يُرسَل أي شيء إلى أي مكان — '
      'حاول مرة أخرى.';

  @override
  String get switchToMessage => 'الانتقال إلى تبويب الرسالة';

  @override
  String get analyseButton => 'حلّلها';

  @override
  String get analysingButton => 'جارٍ التحليل...';

  @override
  String get howItWorksTitle => 'كيف يعمل';

  @override
  String get stepPaste => 'الصق';

  @override
  String get stepPasteBody => 'رابطًا أو الرسالة كاملة التي استلمتها.';

  @override
  String get stepCheck => 'افحص';

  @override
  String get stepCheckBody => 'تبحث القواعد الواضحة عن أنماط احتيال معروفة.';

  @override
  String get stepDecide => 'قرر';

  @override
  String get stepDecideBody => 'مستوى المخاطة، والأسباب، وخطوة آمنة تالية.';

  @override
  String get homeDisclaimer =>
      'يعرض هذا التطبيق علامات تحذير شائعة فقط. لا يستطيع أن يضمن أن شيئاً '
      'ما هو احتيال، ولا أنه آمن — عند الشك، تحقق عبر قناة رسمية.';

  @override
  String get infoSheetTitle => 'كيف يعمل هذا التطبيق';

  @override
  String get infoSheetBody =>
      '1. تُصق رابطاً أو رسالة استلمتها.\n\n'
      '2. تفحص القواعد المدمجة العنوان والنص مقابل أنماط معروفة من الاحتيال: '
      'الاستعجال، والتهديدات، وطلبات كلمات المرور أو الرموز، والجوائز '
      'المزيفة، وانتحال الهوية، وبنية نطاقات مشبوهة.\n\n'
      '3. تحصل على مستوى للمخاطة، والأسباب الدقيقة وراءه، وخطوة عملية '
      'تالية.\n\n'
      'كل سبب يظهر في النتيجة مصدره قاعدة يمكنك قراءتها، وليس نتيجة '
      'مخفية. وإذا كان هناك شرح بالذكاء الاصطناعي، فإنه يضيف صياغة فقط ولا '
      'يغيّر مستوى المخاطة.\n\n'
      'التطبيق لا يفتح أو يزور أو يُنزّل أي رابط.';

  /// The honest limitation required by the product brief: the rules are
  /// English-only, and the user must not assume Arabic text is analysed.
  @override
  String? get detectionCoverageNote =>
      'ملاحظة مهمة: قواعد الكشف تعمل حالياً على النصوص الإنجليزية فقط. لا '
      'يعتمد هذا التطبيق على كشف الاحتيال داخل الرسائل المكتوبة بالعربية '
      'بعد، لذلك قد تمرّ رسالة احتيال عربية من دون أن تُلاحَظ. استخدم النتيجة '
      'كإرشاد، وليست حكماً نهائياً.';

  @override
  String get languageSheetTitle => 'اختر اللغة';

  // -------------------------------------------------------------------------
  // Result screen
  // -------------------------------------------------------------------------

  @override
  String get resultTitle => 'نتيجة التحليل';

  @override
  String get analyseAnother => 'تحليل آخر';

  @override
  String get aiExplanationTitle => 'شرح بالذكاء الاصطناعي';

  @override
  String get aiExternalBadge => 'نموذج خارجي';

  @override
  String get whyThisResult => 'لماذا هذه النتيجة؟';

  @override
  String get contextNotes => 'ملاحظات سياقية';

  @override
  String get whatToDo => 'ما الذي يجب أن تفعله؟';

  @override
  String get aboutThisAnalysis => 'عن هذا التحليل';

  @override
  String get noSignalsTitle =>
      'لم تطابق أي من أنماط التحذير المدمجة هذا المدخل. هذه علامة جيدة، '
      'لكنها ليست ضماناً — توخَّ الحذر مع أي طلب غير متوقع.';

  @override
  String get copyReport => 'نسخ التقرير';

  @override
  String get reportCopied => 'تم نسخ التقرير إلى الحافظة';

  @override
  String get limitationNote =>
      'تنبيه: تُبرز هذه النتيجة علامات تحذير شائعة فقط. لا تثبت أن شيئاً ما '
      'آمن، ولا تفتح أو تُنزّل أي رابط. تحقق دائماً من الطلبات غير '
      'المتوقعة عبر قناة رسمية.';

  @override
  String get linkScanScopeNote =>
      'هذه ليست فحصاً للأمان. يقرأ التطبيق رابط الموقع فقط ولا يفتحه أو '
      'يختبره، لذلك تعني المخاطة المنخفضة عدم وجود علامات تحذير شائعة في '
      'الرابط — ولا تعني أن الموقع آمن أو خالٍ من الثغرات.';

  @override
  String analysedAt(String time, int checks) =>
      'تم التحليل الساعة $time — عدد الفحوصات المطابقة: $checks.';

  @override
  String modeText(AnalysisMode mode) => switch (mode) {
        AnalysisMode.rulesOnly =>
          'مستوى المخاطة وكل الأسباب أعلاه مصدرها القواعد المدمجة في التطبيق. '
              'لا يوجد خدمة ذكاء اصطناعي مهيأة في هذه النسخة.',
        AnalysisMode.rulesAndAi =>
          'مستوى المخاطة والأسباب أعلاه مصدرها القواعد المدمجة في التطبيق. '
              'طُلب من نموذج ذكاء اصطناعي خارجي إضافة شرح بلغة بسيطة. الذكاء '
              'الاصطناعي لا يغيّر مستوى المخاطة.',
        AnalysisMode.rulesWithAiFallback =>
          'مستوى المخاطة والأسباب أعلاه مصدرها القواعد المدمجة في التطبيق. '
              'طُلب شرح بالذكاء الاصطناعي لكن لم يكتمل، لذا تظهر القواعد فقط.',
      };

  @override
  String aiFailureNote(AiFailure failure) => switch (failure) {
        AiFailure.timeout =>
          'السبب: لم تُجب خدمة الذكاء الاصطناعي ضمن المهلة المحدّدة.',
        AiFailure.network =>
          'السبب: تعذّر الوصول إلى خدمة الذكاء الاصطناعي من هذا الجهاز.',
        AiFailure.rateLimited =>
          'السبب: خدمة الذكاء الاصطناعي تتعامل حالياً مع عدد كبير من الطلبات.',
        AiFailure.apiError =>
          'السبب: أعادت خدمة الذكاء الاصطناعي رداً يدل على خطأ.',
        AiFailure.badResponse =>
          'السبب: أعادت خدمة الذكاء الاصطناعي رداً لا يستطيع التطبيق قراءته.',
        AiFailure.unknown =>
          'السبب: توقفت خطوة الذكاء الاصطناعي لسبب غير متوقّع.',
      };

  @override
  String riskLabel(RiskLevel level) => switch (level) {
        RiskLevel.low => 'مخاطر منخفضة',
        RiskLevel.medium => 'مخاطر متوسطة',
        RiskLevel.high => 'مخاطر عالية',
      };

  @override
  String analysisKind(InputKind kind) => switch (kind) {
        InputKind.link => 'تحليل رابط',
        InputKind.message => 'تحليل رسالة',
      };

  @override
  String signalCount(int count) => _count(
        count,
        'إشارة واحدة',
        'إشارتان',
        'إشارات',
        'إشارة',
      );

  @override
  String strongSignalCount(int count) => _count(
        count,
        'إشارة قوية واحدة',
        'إشارتان قويتان',
        'إشارات قوية',
        'إشارة قوية',
      );

  @override
  String warningCount(int count) => _count(
        count,
        'تحذير واحد',
        'تحذيران',
        'تحذيرات',
        'تحذيراً',
      );

  @override
  String contextNoteCount(int count) => _count(
        count,
        'ملاحظة سياقية واحدة',
        'ملاحظتان سياقيتان',
        'ملاحظات سياقية',
        'ملاحظة سياقية',
      );

  @override
  String sourceLabel(IndicatorSource source) => switch (source) {
        IndicatorSource.link => 'رابط',
        IndicatorSource.message => 'رسالة',
      };

  // -------------------------------------------------------------------------
  // Engine output
  // -------------------------------------------------------------------------

  @override
  String headline(RiskLevel level, int signalCount) => switch (level) {
        RiskLevel.high =>
          'تطابقت علامات تحذير قوية. لا تتخذ أي إجراء قبل أن تتحقق.',
        RiskLevel.medium =>
          'تطابقت بعض علامات التحذير. توقّف وتحقق قبل أن تتحرّك.',
        RiskLevel.low => signalCount == 0
            ? 'لم يُعثر على أي علامات تحذير واضحة في هذا المدخل.'
            : 'لم يُعثر إلا على إشارات طفيفة — لا شيء مشبوه بوضوح.',
      };

  @override
  String recommendation(
    RiskLevel level, {
    required bool wantsSecrets,
    required bool wantsMoney,
    required bool hasLink,
    bool hasDownload = false,
  }) {
    final buffer = StringBuffer();
    switch (level) {
      case RiskLevel.high:
        // ذكر الرابط فقط إذا كان الرابط موجوداً فعلاً؛ رسالة بلا رابط لا يجوز
        // أن تُنصح فيها بمغادرة رابط غير موجود.
        buffer.write(
          hasLink
              ? 'لا تفتح الرابط، ولا ترد، ولا ترسل شيئاً. تحقق من المرسل عبر '
                  'قناة رسمية منفصلة — موقعه الرسمي أو رقم كنت تعرفه من قبل — '
                  'قبل أن تفعل أي شيء.'
              : 'لا ترد، ولا ترسل شيئاً. تحقق من المرسل عبر قناة رسمية '
                  'منفصلة — موقعه الرسمي أو رقم كنت تعرفه من قبل — قبل أن تفعل '
                  'أي شيء.',
        );
        break;
      case RiskLevel.medium:
        buffer.write(
          'توقّف قبل التصرّف. تحقق من هوية المرسل فعلاً، وأكد الطلب عبر قناة '
          'رسمية تبحث عنها بنفسك، وليس عبر الرابط أو الرقم الموجود في الرسالة.',
        );
        break;
      case RiskLevel.low:
        buffer.write(
          'لم تُعثر على علامات تحذير قوية، لكن هذا لا يثبت أن الرسالة آمنة. '
          'إذا كانت غير متوقعة، تحقق منها عبر قناة رسمية قبل أن تضغط أو تدفع '
          'أو ترد.',
        );
        break;
    }
    if (wantsSecrets) {
      buffer.write(
        ' لا ترسل كلمة المرور أو الرمز السري أو رمز التحقق لأحد — أي شركة '
        'شرعية لا تطلب ذلك عبر رسالة.',
      );
    }
    if (wantsMoney) {
      buffer.write(
        ' لا تحوّل المال ولا تدفع أي رسوم يُطلب منك دفعها في هذه الرسالة.',
      );
    }
    if (hasDownload) {
      // نسمّي الخطر الحقيقي بدل "صفحة" عامة: الإشارة الحرجة هنا أن برنامجاً
      // سيُثبَّت على الجهاز.
      buffer.write(
        ' لا تُنزّل الملف الذي يشير إليه هذا الرابط، ولا تشغّله.',
      );
    } else if (hasLink && level != RiskLevel.low) {
      buffer.write(
        ' لا تُدخل بياناتك في أي صفحة يفتحها هذا الرابط.',
      );
    }
    return buffer.toString();
  }

  // -------------------------------------------------------------------------
  // Rule output, translated for display
  //
  // Only the wording changes. `id` and `severity` always come from the rule.
  // -------------------------------------------------------------------------

  @override
  String? indicatorTitle(Indicator i) => switch (i.id) {
        'userinfo_at' => 'العنوان يخفي الموقع الحقيقي',
        'malformed' => 'تعذّر قراءة العنوان',
        'homograph' => 'حروف غير معتادة في العنوان',
        'ip_host' => i.params['private'] == '1'
            ? 'العنوان يشير إلى شبكة داخلية'
            : 'العنوان يستخدم أرقاماً بدلاً من اسم نطاق',
        'no_tld' => 'العنوان ينقصه امتداد نطاق',
        'spoofed_structure' => 'اسم العلامة التجارية مستخدم كنطاق فرعي زائف',
        'brand_in_domain' => 'اسم علامة تجارية معروفة داخل عنوان مختلف',
        'brand_impersonation' => 'ينتحل هوية ${i.params['brand'] ?? ''}',
        'suspicious_domain_words' => 'النطاق مليء بعبارات احتيال',
        'suspicious_domain_word' => 'النطاق يحتوي على كلمة مثيرة',
        'excessive_subdomains' => 'عدد كبير بشكل غير معتاد من النطاقات الفرعية',
        'many_hyphens' => 'اسم النطاق مقسوم بشرطات كثيرة',
        'many_digits' => 'النطاق يحتوي على أرقام كثيرة',
        'suspicious_tld' => 'امتداد نطاق يستخدمه المحتالون كثيراً',
        'shortener' => 'الرابط مختصر والوجهة مخفية',
        'http_scheme' => 'الاتصال غير مشفّر',
        'non_standard_port' => 'منفذ شبكة غير معتاد',
        'brand_in_path' => 'اسم علامة تجارية داخل مسار الرابط',
        'checkpoint_path' => 'عنوان الرابط يحتوي كلمات "تحقق"',
        'credential_in_query' => 'الرابط يحمل بيانات سرية في عنوانه',
        'dangerous_download' => 'الرابط يُنزّل برنامجاً',
        'archive_download' => 'الرابط يُنزّل ملفاً مضغوطاً',
        'heavy_encoding' => 'العنوان مرمّز بكثافة',
        'very_long' => 'عنوان طويل جداً',
        'urgency' => 'يخلق استعجالاً وضغط وقت',
        'threat' => 'يهدد بخسارة أو عقوبة',
        'sensitive_request' => 'يطلب معلومات خاصة',
        'sensitive_words' => 'يذكر كلمة مرور أو رمز PIN أو رمز تحقق',
        'payment_demand' => 'يطالب بطريقة دفع غير معتادة',
        'fee_request' => 'يطلب منك دفع رسوم لاستلام شيء',
        'prize_reward' => 'يعرض جائزة لم تشارك في سباقها',
        'money_claim' => 'يطلب منك مطالبة بمبلغ مالي بعينه',
        'impersonation' => 'يدّعي أنه جهة رسمية أو موثوقة',
        'secrecy' => 'يطلب منك الإخفاء',
        'too_good' => 'يبدو جيداً أكثر من اللازم',
        'call_to_action' => 'يدفعك للضغط أو الفتح أو الرد',
        'generic_greeting' => 'تحية عامة بدلاً من اسمك',
        'chain_forward' => 'يطلب منك توجيهها إلى آخرين',
        'off_platform' => 'ينقل الحوار خارج القناة الرسمية',
        'link_in_message' => 'الرسالة تحتوي على رابط',
        'combined_link_request' => 'رابط مقترن بطلب مال أو معلومات',
        _ => null,
      };

  @override
  String? indicatorExplanation(Indicator i) {
    final p = i.params;
    return switch (i.id) {
      'userinfo_at' =>
        'الجزء الذي قبل "@" مجرد عنوان زائف. الموقع الذي ستفتحه فعلاً هو '
            'الذي بعدها، وهذه حيلة كلاسيكية تُستخدم ليبدو الرابط شرعياً.',
      'malformed' =>
        'هذا لا يبدو عنوان موقع مكتملاً، لذا تم فحص جزء منه فقط. كن حذراً '
            'جداً معه.',
      'homograph' =>
        'يستخدم العنوان محارف مرمّزة أو غير قياسية. يستخدم المحتالون ذلك '
            'لجعل موقع يشبه موقعاً آخر بحروف تبدو متشابهة.',
      'ip_host' => p['private'] == '1'
          ? 'الرابط يشير إلى عنوان شبكة داخلية. لا تفتحه إلا إذا أنت منضبط '
              'تلك الأجهزة بنفسك.'
          : 'الرابط يذهب مباشرة إلى رقم IP بدلاً من موقع باسم مفهوم. تُستضاف '
              'صفحات الاحتيال بهذه الطريقة كثيراً لإخفاء هوية من يديرها.',
      'no_tld' =>
        'عنوان الموقع الطبيعي ينتهي بشيء مثل ‎.com أو ‎.org. هذا العنوان لا '
            'ينتهي بشيء كهذا، وقد لا يذهب إلى حيث تتوقع.',
      'spoofed_structure' =>
        'يضع العنوان "${p['official'] ?? ''}" قبل اسم النطاق الحقيقي، لذا '
            'الموقع الذي ستزوره فعلاً يديره شخص آخر.',
      'brand_in_domain' =>
        'يحتوي العنوان على اسم "${p['brand'] ?? ''}" لكنه ليس الموقع الرسمي '
            '(${p['official'] ?? ''}). وضع أسماء العلامات التجارية داخل نطاقات '
            'غريبة حيلة شائعة لكسب الثقة.',
      'brand_impersonation' =>
        'يجمع العنوان بين اسم ${p['brand'] ?? ''} وكلمات مثل '
            '"${_list(p['words'] ?? '')}" بينما ليس هو النطاق الرسمي '
            '${p['official'] ?? ''}. هذه نمط تصيّد موثّق.',
      'suspicious_domain_words' =>
        'اسم النطاق يحتوي على عدة كلمات محمّلة في وقت واحد: '
            '"${_list(p['words'] ?? '')}". المواقع الشرعية نادراً ما تحتاج إلى '
            'هذا الحجم من المؤشرات في عنوانها.',
      'suspicious_domain_word' =>
        'اسم النطاق يتضمن كلمة "${p['word'] ?? ''}"، وهي تُستخدم غالباً '
            'لإعطاء الرابط طابعاً عاجلاً أو رسمياً.',
      'excessive_subdomains' =>
        'يحتوي العنوان على ${p['count'] ?? ''} أجزاء مفصولة بنقاط. العناوين '
            'المتداخلة عميقاً تُستخدم كثيراً لإيهام المستخدم بأنها رابط رسمي '
            'طويل.',
      'many_hyphens' =>
        'الجزء الرئيسي من العنوان يحتوي على ${p['count'] ?? ''} شرطات. '
            'النطاقات المقسومة بشرطات عشوائية شائعة في روابط الاحتيال المولّدة '
            'آلياً.',
      'many_digits' =>
        'يحتوي العنوان على ${p['count'] ?? ''} رقماً، وغالباً ما يعني ذلك أنه '
            'مولّد آلياً ولم يختره شخص أو جهة حقيقية.',
      'suspicious_tld' =>
        'المواقع المنتهية بـ".${p['tld'] ?? ''}" رخيصة التسجيل بالجملة، وردّت '
            ' عنها بلاغات تصيّد كثيرة، فتعامل الرابط بحذر.',
      'shortener' =>
        'هذا رابط مختصر. النص الظاهر لا يخبر إلى أين ستصل فعلاً، لذا لا يمكن '
            'الحكم على الوجهة من الرابط نفسه.',
      'http_scheme' =>
        'الرابط يبدأ بـ"http://" بدلاً من "https://". أي شيء تكتبه على تلك '
            'الصفحة يمكن قراءته أثناء نقله.',
      'non_standard_port' =>
        'يستخدم الرابط المنفذ ${p['port'] ?? ''} بدلاً من المنافذ المعتادة. '
            'المواقع العادية نادراً ما تحتاج إلى ذلك.',
      'brand_in_path' =>
        'مسار الرابط يذكر "${p['brand'] ?? ''}" بينما النطاق مختلف عن '
            '${p['official'] ?? ''}. يُستخدم ذلك غالباً لتبدو الصفحة المزيفة '
            'رسمية.',
      'checkpoint_path' =>
        'يحتوي مسار العنوان على "${_list(p['words'] ?? '')}". كثيراً ما يستخدم '
            'صفحات الاحتيال هذا النوع من الصياغة، فاعتبرها سبباً للتحقق من '
            'المرسل. لم يُفتح الرابط، فلا هذا دليل على ما تطلبه تلك الصفحة.',
      'credential_in_query' =>
        'يحتوي الرابط بالفعل على "${_list(p['keys'] ?? '')}" ضمن معاملاته. '
            'الروابط لا ينبغي أن تحمل كلمات مرور أو رموز تحقق أبداً.',
      'dangerous_download' =>
        'يشير العنوان إلى ملف ".${p['ext'] ?? ''}". تثبيت أو فتح برنامج من '
            'رابط غير متوقع من أسرع الطرق لفقدان السيطرة على الجهاز.',
      'archive_download' =>
        'يشير العنوان إلى أرشيف ".${p['ext'] ?? ''}"، ويمكن أن يخفي محتوياته '
            'الحقيقية. افتح الأرشيفات التي كنت تنتظرها فقط.',
      'heavy_encoding' =>
        'يحتوي الرابط على ${p['count'] ?? ''} حرفاً مرمّزاً، ويمكن استخدام ذلك '
            'لإخفاء الوجهة الحقيقية.',
      'very_long' =>
        'طول الرابط ${p['length'] ?? ''} حرفاً. تُستخدم العناوين الطويلة '
            'غالباً لإخفاء الجزء المشبوه في منتصفها.',
      'urgency' =>
        'الرسالة تدفعك للتصرف فوراً. يُستخدم الضغط لمنعك من التوقف والتأكد '
            'مما إذا كان الطلب أصلياً.',
      'threat' =>
        'الرسالة تحذّرك من حدوث شيء سيء بك ما لم تمتثل. الخوف من أكثر أدوات '
            'الهندسة الاجتماعية استخداماً.',
      'sensitive_request' =>
        'الرسالة تطلب منك إرسال كلمة مرور أو رمز PIN أو رمز تحقق أو بيانات '
            'بنكية. الجهات الشرعية لا تطلب ذلك عبر الرسائل أبداً.',
      'sensitive_words' =>
        'الرسالة تذكر كلمة مرور أو رمز PIN أو رمز تحقق. بذاتها هذه ليست '
            'طلباً، فقد تكون الرسالة تحذّرك منها فقط. تعامل معها بحذر فقط إذا '
            'كانت تشير أيضاً إلى رابط، أو تطلب منك تأكيد شيء أو مشاركته.',
      'payment_demand' =>
        'الرسالة تطلب مالاً بطريقة يصعب تتبعها مثل بطاقات الهدايا أو العملات '
            'الرقمية أو التحويل البنكي. الخدمات الشرعية لا تعمل بهذه الطريقة.',
      'fee_request' =>
        'الرسالة تطلب دفعاً مسبقاً قبل أن تستلم طرداً أو استرداداً أو جائزة '
            'أو وصولاً إلى حسابك. رسوم "الإفراج" المسبقة نمط احتيال كلاسيكي.',
      'prize_reward' =>
        'الرسالة تَعِدك بمال أو جائزة من العدم. تُستخدم الجوائز المزيفة لدفع '
            'الناس إلى دفع "رسوم" أو تسليم بيانات حساباتهم.',
      'money_claim' =>
        'الرسالة تطلب منك المطالبة بمبلغ نقدي بعينه. هذا النوع من الطلبات '
            'غير المسبوقة فخّ شائع، فتحقّق من هوية المرسل قبل أن تتصرّف. وإذا '
            'طلبت منك بعد ذلك دفعاً أو بيانات شخصية، فاعتبر ذلك علامة خطر.',
      'impersonation' =>
        'الرسالة تقدّم نفسها وكأنها من جهة حكومية أو بنك أو شركة شحن. الجهات '
            'الرسمية تتحقق من هويتك عبر قنوات رسمية، لا عبر إرسال روابط في '
            'الرسائل.',
      'secrecy' =>
        'الرسالة تثبّك عن إخبار أحد. يعتمد المحتالون على الصمت حتى لا يتسنى '
            'لأحد تحذيرك.',
      'too_good' =>
        'الرسالة تعد بمال سهل بشكل غير معتاد أو بنتيجة بلا مخاطرة. العوائد '
            'الحقيقية تأتي دائماً بشروط ومخاطر.',
      'call_to_action' =>
        'الرسالة تدفعك نحو خطوة واحدة سريعة. الاحتيال يحتاج منك أن تتحرّق '
            'قبل أن تفكر، لذا من المتوقع أن تكون الخطوة التالية واضحة ومباشرة.',
      'generic_greeting' =>
        'الرسالة تخاطب الجميع بنفس الطريقة. الجهات التي تعرفك فعلاً تستخدم '
            'اسمك أو رقم حسابك.',
      'chain_forward' =>
        'الرسالة تريد الانتشار عبر جهات اتصالك، وهو نمط تداول بين رسائل '
            'السلسلة منذ عقود.',
      'off_platform' =>
        'الرسالة تريد مواصلة التواصل في مكان يصعب التحقق منه أو الإبلاغ عنه، '
            'وهي خطوة شائعة في عمليات الاحتيال الاستثماري والعاطفي.',
      'link_in_message' =>
        'يوجد رابط داخل هذه الرسالة. النص المحيط بالرابط غالباً ما يُكتب فقط '
            'ليجعلك تضغط عليه، فاحكم على الاثنين معاً.',
      'combined_link_request' =>
        'الرسالة تشير إلى رابط وفي نفس الوقت تطلب مالاً أو بيانات شخصية. هذا '
            'المزج من أكثر أشكال رسائل الاحتيال شيوعاً.',
      _ => null,
    };
  }

  // -------------------------------------------------------------------------
  // Plain-text report
  // -------------------------------------------------------------------------

  @override
  String reportHeader(RiskLevel level) =>
      'Scam Detection Field — ${riskLabel(level)}';

  @override
  String reportInputLabel(InputKind kind) => switch (kind) {
        InputKind.link => 'المدخل (رابط):',
        InputKind.message => 'المدخل (رسالة):',
      };

  @override
  String get reportWhyHeading => 'لماذا:';

  @override
  String get reportNoSignals => '- لم تطابق أي علامات تحذير.';

  @override
  String reportReasonLine(String title, String explanation) =>
      '- $title: $explanation';

  @override
  String get reportAiHeading => 'شرح بالذكاء الاصطناعي:';

  @override
  String get reportWhatToDoHeading => 'ما يجب فعله:';

  @override
  String get reportNoteHeading => 'ملاحظة:';

  @override
  String get reportNoteBody =>
      'يعرض علامات تحذير شائعة فقط — وليس ضماناً أن شيئاً ما احتيال أو أنه '
      'آمن.';
}
