// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get notificationOffNoticeTitle => '¿Activar notificaciones?';

  @override
  String get notificationOffNoticeBody => 'Te avisamos al terminar una rutina';

  @override
  String get notificationOffValue => 'Desactivadas';

  @override
  String get appTitle => 'elum';

  @override
  String get commonConfirm => 'Aceptar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String dateYearMonthDay(int year, int month, int day) {
    return '$day/$month/$year';
  }

  @override
  String dateMonthDaySince(int month, int day) {
    return 'Desde el $day/$month';
  }

  @override
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'mon': 'lun',
      'tue': 'mar',
      'wed': 'mié',
      'thu': 'jue',
      'fri': 'vie',
      'sat': 'sáb',
      'sun': 'dom',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String creditResetAt(int month, int day, String weekday, int hour) {
    return '$weekday $day/$month a las $hour:00';
  }

  @override
  String creditResetAtMinute(
    int month,
    int day,
    String weekday,
    int hour,
    int minute,
  ) {
    return '$weekday $day/$month a las $hour h $minute min';
  }

  @override
  String get creditResetFallback => 'el próximo lunes a las 0:00';

  @override
  String get creditResetFallbackMonth => 'el día 1 del próximo mes a las 0:00';

  @override
  String get creditBlockedBusy =>
      'Ya se está creando una rutina.\nPodrás crear otra cuando termine';

  @override
  String creditReceivedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recibiste $count créditos',
      one: 'Recibiste $count crédito',
    );
    return '$_temp0';
  }

  @override
  String get adRewardPreparing => 'Preparando el anuncio';

  @override
  String get adRewardConfirming => 'Comprobando tus créditos';

  @override
  String get adRewardLoadFailed =>
      'Ahora no se puede cargar un anuncio.\nInténtalo de nuevo en un momento';

  @override
  String get adRewardNotWatched =>
      'Mira el anuncio hasta el final para recibir créditos.\nEmpieza de nuevo desde el principio';

  @override
  String get adRewardSlow =>
      'La comprobación de créditos está tardando.\nNo hace falta ver el anuncio otra vez. Revísalo en Mi información → Mis créditos';

  @override
  String get adRewardDailyLimit =>
      'Ya recibiste todos los créditos por anuncios de hoy.\nInténtalo de nuevo mañana';

  @override
  String get adRewardCheckAccount =>
      'Ahora no puedes recibir créditos por anuncios.\nRevisa el estado de tu cuenta';

  @override
  String get adRewardUnavailable =>
      'Ahora no puedes recibir créditos por anuncios.';

  @override
  String get adRewardUnavailableRetry =>
      'Ahora no puedes recibir créditos por anuncios.\nInténtalo de nuevo en un momento';

  @override
  String get adRewardFailed =>
      'No se pudieron recibir los créditos.\nInténtalo de nuevo en un momento';

  @override
  String get commonPopupClose => 'Cerrar ventana';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonScreenNotFound => 'No encontramos esta pantalla';

  @override
  String get commonRetryLater => 'Inténtalo de nuevo en un momento';

  @override
  String get sentenceStop => '.';

  @override
  String get failureHintOffline => 'Revisa tu conexión a internet';

  @override
  String get failureHintTimeout =>
      'La conexión va lenta. Inténtalo de nuevo en un momento.';

  @override
  String get failureHintBadCertificate =>
      'Esta conexión no es segura. Prueba con otra red.';

  @override
  String coachStepLabel(int index, int total, String message) {
    return 'Consejo $index/$total. $message';
  }

  @override
  String get commonAd => 'Anuncio';

  @override
  String get commonAppInfo => 'Información de la app';

  @override
  String get coachCloseHint => 'Cerrar consejos';

  @override
  String get coachNextHint => 'Siguiente consejo';

  @override
  String get coachTapToClose => 'Toca la pantalla para cerrar';

  @override
  String get coachTapToNext => 'Toca la pantalla para seguir';

  @override
  String get loginSceneEyebrow => 'Hoy,';

  @override
  String get loginSceneTitle => 'Paso a paso, juntos';

  @override
  String get appStatusStoreOpenFailedTitle => 'No se pudo abrir la tienda';

  @override
  String get appStatusStoreOpenFailedFallback =>
      'Busca elum en la tienda y actualízala';

  @override
  String get appStatusMaintenanceTitle => 'Estamos en mantenimiento';

  @override
  String get appStatusMaintenanceBody =>
      'Podrás usar elum cuando termine.\nVuelve a mirar en un rato';

  @override
  String get appStatusRecheck => 'Comprobar de nuevo';

  @override
  String get appStatusUpdateTitle =>
      '¡Actualiza ahora y disfruta\ndel nuevo elum!';

  @override
  String get appStatusUpdated => 'Ya actualicé';

  @override
  String get appStatusGoUpdate => 'Ir a actualizar';

  @override
  String routineForeignCreator(String name, String batchim) {
    return 'Rutina creada por $name';
  }

  @override
  String get routineForeignCreatorUnknown => 'Rutina creada por otro tutor';

  @override
  String get routineDefaultTitle => 'Rutina de hoy';

  @override
  String get rewardPresetSnack => 'Un tentempié favorito';

  @override
  String get rewardPresetVideo => '10 minutos de videos';

  @override
  String get rewardPresetPlay => 'Un juego favorito';

  @override
  String get rewardPresetWalk => 'Un paseo';

  @override
  String get rewardPresetCustom => 'Escribir otra';

  @override
  String get roleGuardianWord => 'Tutor';

  @override
  String get roleElumiWord => 'Elumi';

  @override
  String get roleLabelSuffix => ' lo usa';

  @override
  String get roleGuardianDescription => 'Crea y gestiona rutinas';

  @override
  String get roleElumiDescription => 'Hace las rutinas';

  @override
  String get roleSelectTitle => '¿Quién va a usar\neste dispositivo?';

  @override
  String get roleSelectDescription => 'Hay modo tutor y modo Elumi';

  @override
  String get loginKakaoButton => 'Iniciar sesión con Kakao';

  @override
  String get loginNaverButton => 'Iniciar sesión con Naver';

  @override
  String get loginAppleButton => 'Iniciar sesión con Apple';

  @override
  String get loginConnecting => 'Conectando';

  @override
  String get loginLastUsed => 'Último usado';

  @override
  String get loginDuplicateTitle => 'Esta cuenta ya existe';

  @override
  String get loginDuplicateFallback =>
      'Inicia sesión con el método que usaste la primera vez';

  @override
  String get loginOfflineTitle => 'Revisa tu conexión a internet';

  @override
  String get loginOfflineFallback => 'Conéctate e inténtalo de nuevo';

  @override
  String get loginFailedTitle => 'No se pudo iniciar sesión';

  @override
  String get loginFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get consentTitle => 'Acepta los términos';

  @override
  String get consentLoading => 'Cargando los términos';

  @override
  String get consentSaving => 'Guardando';

  @override
  String get consentSaveFailed =>
      'No se pudo guardar tu aceptación. Inténtalo de nuevo.';

  @override
  String get consentDescriptionReady => 'Toca un punto para ver los detalles';

  @override
  String get consentDescriptionNeeded =>
      'Para usar el servicio tienes que aceptar los términos';

  @override
  String get consentAllAgree => 'Aceptar todos los términos';

  @override
  String get consentRequiredTag => 'Obligatorio';

  @override
  String get consentOptionalTag => 'Opcional';

  @override
  String consentDocumentMeta(String label, String version) {
    return '$label · Versión $version';
  }

  @override
  String get consentListTitle => 'Términos y política de privacidad';

  @override
  String get consentGroupRequired => 'Obligatorios';

  @override
  String get consentGroupOptional => 'Opcionales';

  @override
  String get commonElumiName => 'Elumi';

  @override
  String get characterCatLabel => 'Gato';

  @override
  String get characterCatName => 'Ruru';

  @override
  String get characterFoxLabel => 'Zorro';

  @override
  String get characterFoxName => 'Popo';

  @override
  String get imageStyleEmojiLabel => 'Emoji';

  @override
  String get imageStyleEmojiDescription =>
      'Muestra las cosas con emojis bonitos';

  @override
  String get imageStyleSymbolLabel => 'Pictogramas';

  @override
  String get imageStyleSymbolDescription =>
      'Muestra la acción con un dibujo de líneas';

  @override
  String get imageStyleCharacterLabel => 'Dibujos animados';

  @override
  String get imageStyleCharacterDescription =>
      'Un personaje de dibujos lo hace';

  @override
  String get imageStyleRealisticLabel => 'Realista';

  @override
  String get imageStyleRealisticDescription => 'Parecen cosas de verdad';

  @override
  String get imageStyleCreditLabel => 'Créditos';

  @override
  String imageStyleCreditRoutine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count por rutina',
      one: '$count por rutina',
    );
    return '$_temp0';
  }

  @override
  String get imageStyleCreditRoutineFree =>
      'El texto de la rutina no gasta créditos';

  @override
  String imageStyleCreditImage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count por imagen',
      one: '$count por imagen',
    );
    return '$_temp0';
  }

  @override
  String get goalStepByStep => 'Entender lo que hay que hacer, paso a paso';

  @override
  String get goalPrepareItems => 'Preparar por sí mismo lo que necesita';

  @override
  String get goalPrepareNew => 'Prepararse antes para situaciones nuevas';

  @override
  String get goalIndependent => 'Vivir la experiencia de terminar por sí mismo';

  @override
  String onboardingCharacterTitle(String name, String batchim) {
    return 'Elige un amigo para\nacompañar el día de $name';
  }

  @override
  String get onboardingCharacterDescription =>
      'El amigo que elijas te acompaña en el inicio y en la pantalla de recompensas';

  @override
  String get onboardingImageStyleTitle =>
      '¿Cómo quieres que sean\nlas imágenes de las tarjetas?';

  @override
  String get onboardingImageStyleDescription =>
      'Puedes cambiarlo más tarde en Ajustes';

  @override
  String onboardingImageStyleCreditIntroWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Recibes $count créditos cada semana. Úsalos para crear rutinas e imágenes',
      one:
          'Recibes $count crédito cada semana. Úsalo para crear rutinas e imágenes',
    );
    return '$_temp0';
  }

  @override
  String onboardingImageStyleCreditIntroMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Recibes $count créditos cada mes. Úsalos para crear rutinas e imágenes',
      one:
          'Recibes $count crédito cada mes. Úsalo para crear rutinas e imágenes',
    );
    return '$_temp0';
  }

  @override
  String get onboardingImageStyleCreditIntro =>
      'Los créditos sirven para crear rutinas e imágenes';

  @override
  String get onboardingNameTitle => '¿Cómo quieres\nllamar a Elumi?';

  @override
  String get onboardingNameDescription =>
      'En elum llamamos Elumi a quien usa la app\nNo hace falta que sea su nombre real';

  @override
  String get onboardingNameHint => 'Escribe un nombre';

  @override
  String get onboardingNameInviteLink => 'Tengo un código de invitación';

  @override
  String get onboardingCompletionTitle => 'Todo está\nlisto';

  @override
  String get onboardingCompletionProgress => '¡100 % listo!';

  @override
  String get onboardingSplashLogoLabel => 'elum';

  @override
  String get pinCreateTitle => 'Crea una contraseña\nque solo tú conozcas';

  @override
  String get pinConfirmTitle => 'Escribe la contraseña\nuna vez más';

  @override
  String get pinDescription =>
      'Usarás esta contraseña para cambiar al modo tutor';

  @override
  String get pinMismatch => 'Las contraseñas no coinciden. Inténtalo de nuevo.';

  @override
  String get pinInputSemanticLabel => 'Escribir contraseña';

  @override
  String get pinStartButton => 'Empezar';

  @override
  String get pinProfileCreateFailedTitle =>
      'No se pudo crear el perfil de Elumi';

  @override
  String get pinProfileCreateFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get pinSaveFailedTitle => 'No se pudieron guardar tus ajustes';

  @override
  String get pinSaveFailedFallback => 'Toca Empezar de nuevo en un momento';

  @override
  String get elumiSettingsTitle => 'Ajustes';

  @override
  String get elumiSettingsHapticLabel => 'Vibrar al marcar una tarjeta';

  @override
  String get elumiSettingsPraiseSoundLabel =>
      'Sonido de ánimo al marcar una tarjeta';

  @override
  String get elumiSettingsScreenAwakeLabel =>
      'Mantener la pantalla encendida al ver tarjetas';

  @override
  String get elumiSettingsTermsLabel => 'Términos y política de privacidad';

  @override
  String get elumiSettingsLogoutLabel => 'Cerrar sesión';

  @override
  String get elumiSettingsWithdrawLabel => 'Eliminar cuenta';

  @override
  String get elumiSettingsLogoutTitle => '¿Cerrar sesión?';

  @override
  String get elumiSettingsLogoutMessage =>
      'Este dispositivo se desconectará\nPara volver a usarlo, pide\nun código de conexión a un tutor';

  @override
  String get elumiSettingsLogoutFailTitle => 'No se pudo cerrar la sesión';

  @override
  String get elumiSettingsWithdrawTitle => '¿Eliminar tu cuenta?';

  @override
  String get elumiSettingsWithdrawMessage =>
      'Solo se desconecta este dispositivo\nLas rutinas y las estrellas se quedan en el dispositivo del tutor\nPara volver a usarlo, pide\nun código de conexión a un tutor';

  @override
  String get elumiSettingsWithdrawAction => 'Eliminar cuenta';

  @override
  String get inviteRejectedOnElumiDevice =>
      'Este dispositivo no puede aceptar invitaciones\nÁbrelo en el dispositivo de un tutor';

  @override
  String get elumiSettingsWithdrawFailTitle => 'No se pudo eliminar la cuenta';

  @override
  String get elumiSettingsExitFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get linkStatusTitle => 'Dispositivo de Elumi';

  @override
  String get linkStatusRevokeConfirmTitle => '¿Desconectar este dispositivo?';

  @override
  String get linkStatusRevokeConfirmMessage =>
      'Elumi no podrá ver las rutinas en ese dispositivo\nPara volver a conectarlo, crea un código nuevo';

  @override
  String get linkStatusRevokeConfirmAction => 'Desconectar';

  @override
  String get linkStatusRevokeFailTitle => 'No se pudo desconectar';

  @override
  String get linkStatusRevokeFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get linkStatusRevoked => 'Desconectado';

  @override
  String get linkStatusAlreadyRevoked => 'Ya está desconectado';

  @override
  String get linkStatusLoadFailedFallback =>
      'No se pudo cargar el estado de la conexión';

  @override
  String linkDeviceNumbered(int number) {
    return 'Dispositivo de Elumi $number';
  }

  @override
  String get linkStatusConnected => 'Conectado';

  @override
  String get linkStatusRevokeButton => 'Desconectar';

  @override
  String get linkStatusRevokeHint =>
      'Si lo desconectas, Elumi no podrá ver\nlas rutinas en ese dispositivo';

  @override
  String get linkStatusEmpty => 'No hay ningún dispositivo conectado';

  @override
  String linkStatusConnectedBy(String name, String batchim) {
    return 'Conectado por $name';
  }

  @override
  String get linkStatusConnectedByMe => 'Conectado por ti';

  @override
  String linkStatusConnectedByAndSince(String by, String since) {
    return '$by · $since';
  }

  @override
  String get linkStatusAddAction => '+ Conectar otro dispositivo';

  @override
  String get linkStatusConnectAction => 'Conectar el dispositivo de Elumi';

  @override
  String get linkCodeSettingsTitle => 'Conectar el dispositivo de Elumi';

  @override
  String linkCodeAskTitle(String name, String batchim) {
    return '¿Conectar el dispositivo\nde $name?';
  }

  @override
  String linkCodeEnterHint(String name, String batchim) {
    return 'Escribe este código en el dispositivo de $name';
  }

  @override
  String get linkCodeIssueFailedFallback =>
      'No se pudo crear el código. Inténtalo de nuevo.';

  @override
  String get linkCodeSuccessTitle => '¡El dispositivo está conectado!';

  @override
  String get linkCodeStartButton => 'Empezar';

  @override
  String get linkCodeLater => 'Más tarde';

  @override
  String get linkCodeChangesAfter => 'para que cambie el código';

  @override
  String get linkRetryChipLabel => 'Crear un código nuevo';

  @override
  String get linkEnterTitle => 'Escribe el código que\nte dio el tutor';

  @override
  String get linkEnterGuide =>
      'El código está en el dispositivo del tutor, en\nMi información → engranaje → Conectar el dispositivo de Elumi';

  @override
  String get linkEnterGuidePath =>
      'Mi información → engranaje → Conectar el dispositivo de Elumi';

  @override
  String get linkEnterLinkLost =>
      'Se perdió la conexión\nPide un código de conexión nuevo al tutor y escríbelo';

  @override
  String get linkEnterStartButton => 'Empezar';

  @override
  String get linkEnterInputLabel => 'Escribir código de conexión';

  @override
  String get linkEnterWrongCode => 'Ese código no es correcto';

  @override
  String get linkEnterExpired => 'El código caducó. Pide uno nuevo.';

  @override
  String get linkEnterOffline => 'No se pudo conectar. Revisa tu internet.';

  @override
  String get linkEnterFailed => 'No se pudo conectar. Inténtalo de nuevo.';

  @override
  String get commonGuardianName => 'Tutor';

  @override
  String get guardianKindGuardian => 'Tutor';

  @override
  String get guardianKindCaregiver => 'Profesor del centro';

  @override
  String inviteShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '$minutes minuto',
    );
    return 'Cuidemos juntos a Elumi. Toca el enlace de abajo para abrir la app elum con el código de invitación ya puesto.\nEl código de invitación sirve durante $_temp0.\n\n$url\n\nSi el enlace no se abre, escríbelo en la app.\nCódigo de invitación $code';
  }

  @override
  String get guardiansEditTitle => 'Cambiar mi nombre';

  @override
  String get guardiansEditDescription =>
      'Es el nombre que ven las personas que cuidan a Elumi contigo.\nNo hace falta que sea tu nombre real';

  @override
  String get guardiansEditNameHint => 'Mamá, Papá, Profe';

  @override
  String get guardiansEditSave => 'Guardar';

  @override
  String get guardiansLeaveConfirmTitle => '¿Dejar de cuidar juntos?';

  @override
  String get guardiansLeaveConfirmMessageLast =>
      'No hay otros tutores\nSi sales, se borrarán las rutinas creadas con Elumi y las estrellas reunidas\nNo se puede deshacer';

  @override
  String get guardiansLeaveConfirmMessageOthers =>
      'Si conectaste el dispositivo de Elumi, se desconectará\nOtro tutor tendrá que crear un código de conexión nuevo para volver a usarlo\nSe borrarán las rutinas que creaste\nLas rutinas y estrellas de Elumi y de los demás tutores se quedan';

  @override
  String get guardiansLeaveConfirmAction => 'Dejarlo';

  @override
  String get guardiansLeaveTypeTitle => 'Una comprobación más';

  @override
  String guardiansLeaveTypeMessage(String phrase) {
    return 'Se borrarán Elumi, las rutinas y las estrellas.\nEscribe \'$phrase\'\ntal como aparece abajo';
  }

  @override
  String get guardiansLeaveTypePhrase => 'Salir';

  @override
  String get guardiansLeaveTypeAction => 'Salir';

  @override
  String get guardiansLeaveFailTitle => 'No se pudo salir';

  @override
  String get guardiansLeaveFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String guardiansLeft(String name) {
    return 'Saliste de $name';
  }

  @override
  String get guardiansNameEditFailTitle => 'No se pudo cambiar el nombre';

  @override
  String get guardiansNameEditFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get guardiansTitle => 'Personas que cuidan contigo';

  @override
  String get guardiansNoProfileMessage =>
      'No hay ningún Elumi para ver quién lo cuida contigo';

  @override
  String get guardiansNoProfileDescription => 'Primero añade a Elumi';

  @override
  String get guardiansIntro => 'Familia o profesores que crean rutinas contigo';

  @override
  String get guardiansLoadFailedFallback =>
      'No se pudo cargar quién cuida contigo';

  @override
  String get guardiansEmptyMessage =>
      'No encontramos a nadie que cuide contigo';

  @override
  String get guardiansAloneHint =>
      'Por ahora cuidas a Elumi tú solo. Invita a tu familia o a un profesor.';

  @override
  String get guardiansNameScopeHint =>
      'Este nombre solo lo ven quienes cuidan contigo. En Historias se ve tu apodo de Mi información';

  @override
  String get guardiansInviteAction => 'Invitar a otro tutor';

  @override
  String get guardiansEnterCodeAction => 'Escribir un código de invitación';

  @override
  String get guardiansLeaveAction => 'Dejar de cuidar juntos';

  @override
  String get guardiansLeaveHintAlone =>
      'Eres el único tutor, así que al salir se borran Elumi, las rutinas y las estrellas';

  @override
  String get guardiansLeaveHintWithOthers =>
      'Solo se borran las rutinas que hiciste tú';

  @override
  String inviteCodeGuestJoinedTitle(String name) {
    return '$name se unió';
  }

  @override
  String get guardiansMeBadge => 'Yo';

  @override
  String guardiansPeopleHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas cuidan en equipo',
      one: '$count persona cuida en equipo',
    );
    return '$_temp0';
  }

  @override
  String get guardiansInviteHeader => 'Invitar';

  @override
  String get guardiansRenameAction => 'Cambiar nombre';

  @override
  String get inviteCodeShareFailTitle => 'No se pudo enviar el enlace';

  @override
  String get inviteCodeShareFailFallback => 'Dile tú mismo el código';

  @override
  String get inviteCodeTitle => 'Código de invitación';

  @override
  String get inviteCodeShareButton => 'Enviar como enlace';

  @override
  String get inviteCodeHeaderTitle =>
      'Comparte el código con\nel tutor que se une';

  @override
  String inviteCodeAsk(String name, String batchim) {
    return 'Quien reciba el código cuidará de $name contigo';
  }

  @override
  String get inviteCodeNoProfileMessage =>
      'No hay ningún Elumi para cuidar en equipo';

  @override
  String get inviteCodeNoProfileDescription => 'Primero añade a Elumi';

  @override
  String get inviteCodeIssueFailedFallback =>
      'No se pudo crear el código de invitación';

  @override
  String get inviteEnterLinkInvalid =>
      'Este enlace de invitación no es correcto. Pide que te lo envíen de nuevo. (E-INV-LINK)';

  @override
  String get inviteEnterFormInvalid =>
      'El código de invitación no es correcto (E-INV-FORM)';

  @override
  String inviteJoined(String name, String batchim) {
    return 'Ahora cuidas de $name en equipo';
  }

  @override
  String get inviteEnterNotFound => 'El código de invitación no es correcto';

  @override
  String get inviteEnterExpired =>
      'El código de invitación caducó. Pide uno nuevo.';

  @override
  String get inviteEnterTooManyAttempts => 'Inténtalo de nuevo en un momento';

  @override
  String get inviteEnterAlreadyGuardian => 'Ya cuidas de este Elumi';

  @override
  String get inviteEnterForbiddenForElumi =>
      'No puedes hacer esto en el dispositivo de Elumi';

  @override
  String get inviteEnterInvalidInput =>
      'El código de invitación no es correcto';

  @override
  String get inviteEnterOffline =>
      'No se pudo conectar. Revisa tu conexión a internet.';

  @override
  String get inviteEnterOther => 'No se pudo conectar. Inténtalo de nuevo.';

  @override
  String get inviteEnterConsentFailTitle =>
      'No se pudo introducir el código de invitación';

  @override
  String get inviteEnterConsentFallback => 'Primero acepta los términos';

  @override
  String get inviteEnterStartButton => 'Empezar';

  @override
  String get inviteEnterManualLink => 'Introducir otro código';

  @override
  String get inviteEnterTitle => 'Introduce el\ncódigo de invitación';

  @override
  String get inviteEnterDescriptionFromLink =>
      'Es el código de invitación del enlace. Si es correcto, toca Empezar.';

  @override
  String get inviteEnterDescriptionManual =>
      'El código está en el dispositivo del otro tutor,\nen Mi información → Tutores';

  @override
  String get inviteEnterDescriptionPath => 'Mi información → Tutores';

  @override
  String get inviteEnterSemanticsFromLink => 'Código de invitación del enlace';

  @override
  String get inviteEnterSemanticsInput => 'Introducir código de invitación';

  @override
  String get profileSwitchChanged => 'Cambiaste de Elumi';

  @override
  String get profileSwitchTitle => 'Cambiar de Elumi';

  @override
  String get profileSwitchLoadFailedFallback =>
      'No se pudo cargar la lista de Elumi';

  @override
  String get profileSwitchLoadFailedMessage =>
      'No se pudo cargar la lista de Elumi';

  @override
  String profileSwitchSelected(String name) {
    return '$name, el Elumi que estás viendo';
  }

  @override
  String get noticeHideWeek => 'No mostrar en una semana';

  @override
  String noticeHideDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'No mostrar en $days días',
      one: 'No mostrar en $days día',
    );
    return '$_temp0';
  }

  @override
  String noticeLinkOpenFailed(String code) {
    return 'No se pudo abrir el enlace ($code)';
  }

  @override
  String get noticeCloseBarrier => 'Cerrar aviso';

  @override
  String get cardPhotoTooLarge => 'Esta foto es demasiado grande. Elige otra.';

  @override
  String get cardPhotoWrongType => 'Solo puedes añadir fotos JPG o PNG';

  @override
  String get cardPhotoUnreadable => 'No se pudo leer esta foto. Elige otra.';

  @override
  String get cardPhotoPickFailed =>
      'No se pudo obtener la foto. Inténtalo de nuevo.';

  @override
  String get routineLoadingPrepareTitle =>
      'Lumi está ordenando\nlo que escribiste';

  @override
  String get routineLoadingGenerateTitle =>
      'Lumi está creando\nlas tarjetas de acción';

  @override
  String get routineStageReviewSituation => 'Leyendo lo que escribiste';

  @override
  String get routineStageTidyEssentials => 'Dejando solo lo importante';

  @override
  String get routineStageThinkQuestions => 'Pensando en más preguntas';

  @override
  String get routineStageReadRoutine => 'Leyendo la rutina de hoy';

  @override
  String get routineStageFindItems => 'Buscando las cosas clave que llevar';

  @override
  String get routineStageOrderSteps => 'Poniendo los pasos en orden';

  @override
  String get suggestionRainyText => 'Ir a la escuela un día de lluvia';

  @override
  String get suggestionRainyPrompt =>
      'Quiero prepararme para ir a la escuela con paraguas un día de lluvia';

  @override
  String get suggestionHospitalText => 'Prepararse para ir al hospital';

  @override
  String get suggestionHospitalPrompt =>
      'Tenemos que ir al hospital y quiero prepararlo para que Elumi no tenga miedo';

  @override
  String get suggestionTripText => 'Prepararse para una excursión';

  @override
  String get suggestionTripPrompt =>
      'Quiero ordenar lo que hay que llevar la mañana de la excursión';

  @override
  String get suggestionNewPlaceText => 'Visitar un lugar nuevo';

  @override
  String get suggestionNewPlacePrompt =>
      'Quiero ayudar a Elumi a sentirse listo antes de ir a un lugar nuevo';

  @override
  String get suggestionAfterSchoolText =>
      'Prepararse para la clase extraescolar de verano';

  @override
  String get suggestionAfterSchoolPrompt =>
      'Quiero ordenar los pasos para prepararse para la clase extraescolar en vacaciones';

  @override
  String get guardianHomeTodayRoutine => 'Rutina de hoy';

  @override
  String get guardianHomePastRoutine => 'Rutinas anteriores';

  @override
  String get guardianHomeGoChildScreen => 'Ir al modo Elumi';

  @override
  String get notificationBellLabel => 'Notificaciones';

  @override
  String get notificationBellUnreadLabel => 'Tienes notificaciones sin leer';

  @override
  String get notificationTabNotifications => 'Notificaciones';

  @override
  String get notificationTabNotices => 'Avisos';

  @override
  String get notificationDayToday => 'Hoy';

  @override
  String get notificationDayYesterday => 'Ayer';

  @override
  String get notificationDayEarlier => 'Antes';

  @override
  String get notificationMarkAllRead => 'Marcar todo como leído';

  @override
  String get notificationEmpty => 'Aún no hay notificaciones';

  @override
  String get notificationNoticeEmpty => 'Aún no hay avisos';

  @override
  String get notificationNoticeFailed => 'No se pudieron cargar los avisos';

  @override
  String get notificationSettingsTitle => 'Ajustes de notificaciones';

  @override
  String get notificationSettingAll => 'Todas las notificaciones';

  @override
  String get notificationSettingRoutineCompleted =>
      'Cuando Elumi termina una rutina';

  @override
  String get notificationSettingRoutineSent =>
      'Cuando otro tutor envía una rutina';

  @override
  String get notificationSettingCoGuardianJoined =>
      'Cuando se une un tutor nuevo';

  @override
  String get notificationSettingCreditRefilled =>
      'Cuando se recargan los créditos de la semana';

  @override
  String get notificationSettingFeedbackResolved =>
      'Cuando revisamos tu opinión';

  @override
  String get notificationSettingTalkCommented =>
      'Historias: cuando comentan mi publicación';

  @override
  String get notificationSettingTalkImported =>
      'Historias: cuando alguien se lleva mi publicación';

  @override
  String get notificationPermissionOff =>
      'Las notificaciones del dispositivo están desactivadas';

  @override
  String get notificationTurnOnDeviceNotification => 'Activar';

  @override
  String get notificationSettingSaveFailed =>
      'No se pudieron guardar los ajustes';

  @override
  String get notificationSettingLoadFailed =>
      'No se pudieron cargar los ajustes';

  @override
  String get notificationListFailed =>
      'No se pudieron cargar las notificaciones';

  @override
  String get notificationProfileUnavailable =>
      'Ya no puedes ver las notificaciones de este Elumi';

  @override
  String notificationRoutineCompletedOne(String title) {
    return 'Terminó la rutina \'$title\'';
  }

  @override
  String notificationRoutineCompletedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Terminó $count rutinas',
      one: 'Terminó $count rutina',
    );
    return '$_temp0';
  }

  @override
  String get notificationRoutineCompletedNoTitle => 'Terminó una rutina';

  @override
  String notificationRoutineSent(String title) {
    return 'Otro tutor envió la rutina \'$title\'';
  }

  @override
  String get notificationRoutineSentNoTitle =>
      'Otro tutor envió una rutina nueva';

  @override
  String get notificationCoGuardianJoined => 'Se unió un tutor nuevo';

  @override
  String get notificationCreditRefilled =>
      'Se recargaron los créditos de la semana';

  @override
  String get notificationFeedbackResolved => 'Revisamos tu opinión';

  @override
  String notificationTalkPostCommented(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tu publicación recibió $count comentarios',
      one: 'Tu publicación recibió $count comentario',
    );
    return '$_temp0';
  }

  @override
  String notificationTalkPostImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tutores se llevaron tu publicación',
      one: '$count tutor se llevó tu publicación',
    );
    return '$_temp0';
  }

  @override
  String get notificationWeeklyReportReady =>
      'El informe de la semana pasada está listo';

  @override
  String get notificationAdminMessageFallback => 'Un mensaje de elum';

  @override
  String guardianHomeGreeting(String name) {
    return 'Hola,\n$name 👋🏻';
  }

  @override
  String get guardianHomeSubtitle => '¿Qué rutina preparamos hoy?';

  @override
  String get pinChangeMismatchCreate =>
      'Las contraseñas no coinciden. Inténtalo de nuevo.';

  @override
  String get pinChangeMismatch =>
      'Las contraseñas no coinciden. Inténtalo de nuevo.';

  @override
  String get pinChangeCreateFailedTitle => 'No se pudo crear la contraseña';

  @override
  String get pinChangeFailedTitle => 'No se pudo cambiar la contraseña';

  @override
  String get pinChangeFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get pinChangeCreatedSnack => 'Creaste la contraseña';

  @override
  String get pinChangeChangedSnack => 'Cambiaste la contraseña';

  @override
  String get pinChangeVerifyTitle => 'Introduce tu\ncontraseña actual';

  @override
  String get pinChangeCreateTitle =>
      'Crea una contraseña\npara este dispositivo';

  @override
  String get pinChangeCreateDescription =>
      'Cada dispositivo tiene su propia contraseña\nPuede ser la misma que antes';

  @override
  String get pinModeHint => 'Usarás esta contraseña para cambiar al modo tutor';

  @override
  String get pinChangeEnterTitle => 'Introduce tu\nnueva contraseña';

  @override
  String get pinChangeCreateConfirmTitle =>
      'Introduce la contraseña\nuna vez más';

  @override
  String get pinChangeConfirmTitle => 'Introduce la contraseña\nuna vez más';

  @override
  String get pinChangeConfirmHint =>
      'Ya casi terminas de cambiar la contraseña';

  @override
  String get pinChangeHeaderTitle => 'Cambiar contraseña';

  @override
  String get pinChangeSave => 'Guardar';

  @override
  String get pinChangeInputLabel => 'Introducir contraseña';

  @override
  String get rewardSaveFailedTitle => 'No se pudo guardar la recompensa';

  @override
  String get rewardSaveFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get rewardWhyTitle => '¿Por qué una recompensa?';

  @override
  String get rewardWhyMessage =>
      'Cuando algo bueno espera al final de la rutina, Elumi encuentra fuerzas para terminarla.\nAlgo pequeño que puedas dar hoy funciona mejor que un regalo dentro de un mes.\nTambién puedes hacer una rutina sin recompensa.';

  @override
  String get rewardHeadlineTitle =>
      '¿Qué recompensa llega\ndespués de la rutina?';

  @override
  String get rewardHeadlineBody =>
      'Será una gran motivación para terminar la rutina';

  @override
  String get rewardLater => 'Quizás más tarde';

  @override
  String get imageStyleChangedSnack => 'Cambiaste el estilo de dibujo';

  @override
  String get imageStyleSaveFailedTitle =>
      'No se pudo guardar el estilo de dibujo';

  @override
  String get imageStyleSaveFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get imageStyleTitle => 'Estilo de dibujo';

  @override
  String get routineLoadingBlockedTitle => 'Ahora no se puede crear';

  @override
  String get routineLoadingPrepareFailed =>
      'No se pudieron preparar las preguntas';

  @override
  String get routineLoadingGenerateFailed =>
      'No se pudieron crear las tarjetas';

  @override
  String get routineLoadingInputNeededTitle =>
      'Cuéntanos de qué trata la rutina';

  @override
  String get routineLoadingEditInput => 'Escribir de nuevo';

  @override
  String routineLoadingPercent(int percent) {
    return '$percent% completado';
  }

  @override
  String get routineLoadingRetry => 'Intentar de nuevo';

  @override
  String get routineLoadingHome => 'Ir al inicio';

  @override
  String get draftRoutinesTitle => 'Borradores';

  @override
  String get draftRoutinesLoadFailedFallback =>
      'No se pudieron cargar los borradores';

  @override
  String get draftRoutinesDeleteLabel => 'Borrar borrador';

  @override
  String get draftRoutinesDeleteConfirmTitle => '¿Borrar este borrador?';

  @override
  String get draftRoutinesDeleteAction => 'Borrar';

  @override
  String get draftRoutinesDeleteFailedTitle => 'No se pudo borrar el borrador';

  @override
  String get draftRoutinesDeleteFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get draftRoutinesRewardUnset => 'Aún sin recompensa';

  @override
  String get draftRoutinesRewardLabel => 'Al terminar';

  @override
  String get draftRoutinesResume => 'Continuar';

  @override
  String get draftRoutinesEmptyTitle => 'No hay rutinas sin terminar';

  @override
  String get draftRoutinesEmptyBody =>
      'Si paras mientras haces una rutina, se queda aquí';

  @override
  String get cardReviewDeleteConfirmTitle => '¿Borrar esta tarjeta?';

  @override
  String get cardReviewDeleteAction => 'Borrar';

  @override
  String get cardReviewSoundFailedTitle => 'No se pudo reproducir el sonido';

  @override
  String get cardReviewSoundFailedFallback =>
      'Activa el sonido del dispositivo y toca de nuevo';

  @override
  String get cardReviewSaveFailedTitle => 'No se pudo guardar la rutina';

  @override
  String get cardReviewSaveFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get cardReviewEditFailedTitle => 'No se pudieron guardar los cambios';

  @override
  String get cardReviewEditFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get cardReviewAddFailedTitle => 'No se pudo añadir la tarjeta';

  @override
  String get cardReviewAddFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get cardImageGeneratingLabel => 'Creando la imagen';

  @override
  String get cardImageNoCreditToast =>
      'No hay suficientes créditos, así que pusimos una imagen básica';

  @override
  String get cardImageUnavailableToast =>
      'No se pudo crear la imagen, así que pusimos una imagen básica';

  @override
  String get cardImageMissingAfterCreateToast =>
      'Las tarjetas sin dibujo recibieron uno básico. Puedes crear un dibujo con IA al editar la tarjeta';

  @override
  String get cardReviewReorderDone => 'Listo';

  @override
  String get cardReviewSave => 'Guardar tarjetas';

  @override
  String get routineInputTitle => '¿Qué hace falta\nhoy?';

  @override
  String get routineInputSubtitle =>
      'Lumi, tu ayudante de IA, lo divide en pasos pequeños';

  @override
  String get routineInputHint => 'Escríbelo como lo dirías';

  @override
  String get routineInputPrivacyNotice =>
      'No escribas datos personales como nombres, escuelas, hospitales o diagnósticos';

  @override
  String get guardianSettingsLogoutConfirmTitle => '¿Cerrar sesión?';

  @override
  String get guardianSettingsWithdrawConfirmTitle => '¿Eliminar tu cuenta?';

  @override
  String get guardianSettingsWithdrawConfirmMessage =>
      'Se borrarán todas las rutinas y estrellas\nNo volverán aunque inicies sesión de nuevo';

  @override
  String get guardianSettingsWithdrawConfirmAction => 'Eliminar cuenta';

  @override
  String get guardianSettingsWithdrawFailedTitle =>
      'No se pudo eliminar la cuenta';

  @override
  String get guardianSettingsWithdrawFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get guardianSettingsWithdrawAppStoreSubscriptionNotice =>
      'Tu suscripción Pro sigue activa después de eliminar la cuenta.\nCancélala tú mismo\nen la App Store';

  @override
  String get guardianSettingsWithdrawGooglePlaySubscriptionNotice =>
      'Al eliminar la cuenta se detiene el próximo\npago de tu suscripción Pro de Google Play';

  @override
  String get guardianSettingsWithdrawProNotice =>
      'También se eliminará tu plan Pro';

  @override
  String guardianSettingsWithdrawProGiftNotice(String date) {
    return 'También se eliminará tu regalo Pro,\nválido hasta el $date';
  }

  @override
  String get guardianSettingsWithdrawProTrialNotice =>
      'También se eliminará tu prueba de Pro';

  @override
  String guardianSettingsWithdrawCreditsNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count créditos restantes',
      one: '$count crédito restante',
    );
    return 'También se eliminarán tus $_temp0';
  }

  @override
  String guardianSettingsWithdrawCreditsWithPurchasedNotice(
    int count,
    int purchased,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count créditos restantes',
      one: '$count crédito restante',
    );
    String _temp1 = intl.Intl.pluralLogic(
      purchased,
      locale: localeName,
      other: '$purchased créditos comprados',
      one: '$purchased crédito comprado',
    );
    return 'También se eliminarán tus $_temp0\nIncluye $_temp1';
  }

  @override
  String get guardianSettingsWithdrawCreditsUnknownNotice =>
      'También se eliminarán tus créditos restantes';

  @override
  String get guardianSettingsWithdrawAppStoreStepTitle =>
      'Primero cancela tu suscripción de la App Store';

  @override
  String get guardianSettingsWithdrawAppStoreStepMessage =>
      'Si solo eliminas la cuenta, los pagos continúan\nAun así, puedes eliminarla sin cancelar';

  @override
  String get guardianSettingsWithdrawAppStoreStepContinue => 'Continuar';

  @override
  String get guardianSettingsWithdrawDone =>
      'Eliminamos tu cuenta. Gracias por usar elum';

  @override
  String get guardianSettingsWithdrawTypeTitle => 'Una comprobación más';

  @override
  String guardianSettingsWithdrawTypeMessage(String phrase) {
    return 'Escribe \'$phrase\'\nexactamente como aparece abajo';
  }

  @override
  String get guardianSettingsWithdrawTypePhrase => 'Eliminar cuenta';

  @override
  String get guardianSettingsWithdrawTypeAction => 'Eliminar cuenta';

  @override
  String get guardianSettingsTitle => 'Ajustes';

  @override
  String get guardianSettingsPeople => 'Tutores';

  @override
  String get guardianSettingsDrafts => 'Borradores';

  @override
  String get guardianSettingsPinChange => 'Cambiar contraseña';

  @override
  String get guardianSettingsTerms => 'Términos y política de privacidad';

  @override
  String get guardianSettingsFeedback => 'Enviar opinión';

  @override
  String get feedbackTitle => 'Enviar opinión';

  @override
  String get feedbackHint => 'Cuéntanos qué te costó usar';

  @override
  String get feedbackIncludeLog =>
      'Enviar el registro de la app y los datos del dispositivo';

  @override
  String get feedbackSend => 'Enviar';

  @override
  String get feedbackSent => 'Enviamos tu opinión';

  @override
  String get feedbackFailedTitle => 'No se pudo enviar tu opinión';

  @override
  String get feedbackFailedFallback =>
      'Tu mensaje sigue aquí. Inténtalo de nuevo en un momento';

  @override
  String get guardianSettingsLogout => 'Cerrar sesión';

  @override
  String get guardianSettingsWithdraw => 'Eliminar cuenta';

  @override
  String get guardianSettingsLinkConnected => 'Dispositivo de Elumi';

  @override
  String get guardianSettingsLinkConnect => 'Conectar el dispositivo de Elumi';

  @override
  String get guardianSettingsLinkStatus => 'Conectado';

  @override
  String get guardianSettingsProfileSwitch => 'Cambiar de Elumi';

  @override
  String get guardianSettingsImageStyle => 'Estilo de dibujo';

  @override
  String get guardianSettingsHaptic => 'Vibrar al marcar una tarjeta';

  @override
  String get guardianSettingsPraiseSound =>
      'Sonido de elogio al marcar una tarjeta';

  @override
  String get guardianSettingsScreenAwake =>
      'Mantener la pantalla encendida al ver tarjetas';

  @override
  String get questionMakeCards => 'Crear tarjetas';

  @override
  String get questionCustomAdd => '+ Escribir la mía';

  @override
  String get questionCustomHint => 'Escríbelo aquí';

  @override
  String get questionCustomClose => 'Cerrar escritura';

  @override
  String questionClearLabel(String label) {
    return 'Borrar $label';
  }

  @override
  String cardReviewMade(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Creaste $count tarjetas',
      one: 'Creaste $count tarjeta',
    );
    return '$_temp0';
  }

  @override
  String get cardReviewRewardLead => 'Al terminar: ';

  @override
  String get cardReviewRewardSet => 'Elegir una recompensa';

  @override
  String get cardReviewReorderHint =>
      'Mantén pulsada una tarjeta para cambiar el orden';

  @override
  String get cardReviewToolReorder => 'Cambiar el orden de las tarjetas';

  @override
  String get cardReviewToolEdit => 'Editar esta tarjeta';

  @override
  String get cardReviewToolAdd => 'Añadir una tarjeta';

  @override
  String get cardReviewReorderTitle => 'Cambiar el orden de las tarjetas';

  @override
  String get cardReviewReorderCancel => 'Cancelar el cambio de orden';

  @override
  String get cardReviewEmptyTitle => 'Aún no hay tarjetas';

  @override
  String get cardReviewEmptyBody =>
      'Crea la rutina otra vez desde el principio';

  @override
  String get cardReviewEmptyAction => 'Crear de nuevo';

  @override
  String get cardMoveForward => 'Mover antes';

  @override
  String get cardMoveBackward => 'Mover después';

  @override
  String get cardSpeakStop => 'Dejar de leer';

  @override
  String get cardSpeak => 'Escuchar';

  @override
  String get cardDeleteLabel => 'Quitar esta tarjeta';

  @override
  String get cardAddPhoto => 'Añadir foto';

  @override
  String get cardViewerBarrierLabel => 'Cerrar tarjeta';

  @override
  String get cardViewerSoundFailedTitle => 'No se pudo reproducir el sonido';

  @override
  String get cardViewerSoundFailedFallback =>
      'Activa el sonido del dispositivo y toca otra vez';

  @override
  String get cardViewerClose => 'Cerrar tarjeta';

  @override
  String get cardEditAddTitle => 'Añadir una tarjeta nueva';

  @override
  String get cardEditTitle => 'Editar tarjeta';

  @override
  String get cardEditFieldTitle => 'Título';

  @override
  String get cardEditTitleHint => 'Escribe el título de la tarjeta';

  @override
  String get cardEditFieldDescription => 'Descripción';

  @override
  String get cardEditDescriptionHint => 'Escribe la descripción de la tarjeta';

  @override
  String get cardEditAddAction => 'Añadir';

  @override
  String get cardEditDoneAction => 'Listo';

  @override
  String get cardPhotoPermissionTake => 'Hacer una foto';

  @override
  String get cardPhotoPermissionGallery => 'Elegir de la galería';

  @override
  String get cardPhotoPermissionOpenSettings => 'Abrir ajustes';

  @override
  String get cardPhotoPermissionCameraTitle => 'No se puede usar la cámara';

  @override
  String get cardPhotoPermissionGalleryTitle => 'No se pueden ver tus fotos';

  @override
  String get cardPhotoPermissionCameraBody =>
      'Activa la cámara en los ajustes del dispositivo para hacer fotos';

  @override
  String get cardPhotoPermissionGalleryBody =>
      'Activa el acceso a fotos en los ajustes del dispositivo para elegirlas';

  @override
  String get cardPhotoSettingsFailedTitle => 'No se pudieron abrir los ajustes';

  @override
  String get cardPhotoSettingsFailedFallback =>
      'Actívalo tú mismo en los ajustes del dispositivo';

  @override
  String get cardPhotoSourceTake => 'Hacer una foto';

  @override
  String get cardPhotoSourceGallery => 'Elegir de la galería';

  @override
  String cardPhotoUploadFailedDialog(String message) {
    return 'No se pudo subir la foto.\n$message';
  }

  @override
  String get cardPhotoChange => 'Cambiar foto';

  @override
  String get cardPhotoUploading => 'Subiendo la foto';

  @override
  String get cardPhotoUploadFailed => 'No se pudo subir la foto';

  @override
  String get cardPhotoRetry => 'Reintentar';

  @override
  String get creditCardTitle => 'IA esta semana';

  @override
  String get creditCardTitleMonth => 'Creaciones con IA este mes';

  @override
  String get creditCardLoading => 'Cargando el uso de IA de esta semana';

  @override
  String get creditCardLoadingMonth => 'Cargando el uso de IA de este mes';

  @override
  String get creditCardLoadFailed => 'No se pudo cargar el uso';

  @override
  String get creditCardRetry => 'Reintentar';

  @override
  String get creditGenerating => 'Creando la rutina';

  @override
  String get creditExhausted => 'Ya usaste todos tus créditos de esta semana';

  @override
  String get creditExhaustedMonth => 'Ya usaste todos tus créditos de este mes';

  @override
  String get creditExhaustedStillOk =>
      'Puedes seguir viendo tus rutinas y editarlas tú mismo';

  @override
  String get creditInfoLabel => 'Sobre los créditos de IA';

  @override
  String creditAmountLeft(int available, int weekly) {
    return 'Te quedan $available / $weekly créditos';
  }

  @override
  String creditAmountRest(int weekly) {
    return ' / $weekly créditos restantes';
  }

  @override
  String aiCreditResetLine(String reset) {
    return 'Se recargan el $reset';
  }

  @override
  String get routineCreateButton => 'Crear una rutina nueva';

  @override
  String get routineSwipeDelete => 'Borrar rutina';

  @override
  String get routineSwipeEdit => 'Editar rutina';

  @override
  String get routineFlowHomeLabel => 'Ir al inicio';

  @override
  String get routineFlowDraftLabel => 'Borrador';

  @override
  String get routineFlowLeaveStay => 'Seguir creando';

  @override
  String get routineFlowLeaveConfirm => 'Salir';

  @override
  String get routineLeaveDiscardTitle => '¿Dejar de crear esta rutina?';

  @override
  String get routineLeaveDiscardMessage =>
      'Si sales ahora, no se guardará lo que escribiste';

  @override
  String get routineLeaveDraftWhenReadyTitle =>
      '¿Salir y dejarla como borrador?';

  @override
  String get routineLeaveDraftWhenReadyMessage =>
      'Cuando las tarjetas estén listas, quedará en Borradores\nPuedes seguir desde Mi información';

  @override
  String get routineLeaveDraftTitle => '¿Salir y dejarla como borrador?';

  @override
  String get routineLeaveDraftMessage =>
      'Puedes seguir desde\nBorradores en Mi información';

  @override
  String get routineLeaveEditTitle => '¿Salir sin guardar?';

  @override
  String get routineLeaveEditMessage =>
      'Las tarjetas que quitaste solo se van al tocar Guardar';

  @override
  String get routineTileRewardLabel => 'Al terminar';

  @override
  String get routineTileRerun => 'Repetir rutina';

  @override
  String get routineDetailReorderFailedTitle => 'No se pudo guardar el orden';

  @override
  String get routineDetailReorderFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get routineDetailRerun => 'Repetir rutina';

  @override
  String get routineDetailEdit => 'Editar';

  @override
  String routineDetailTodayProgress(int done, int total) {
    return 'Hoy: $done/$total hechas';
  }

  @override
  String routineDetailPastProgress(int done, int total) {
    return '$done/$total hechas';
  }

  @override
  String get routineDetailExportLabel => 'Imprimir';

  @override
  String get routineDetailFinishedToday => 'Esta rutina ya está terminada';

  @override
  String get routineDetailOpenHint => 'Toca para ver la tarjeta más grande';

  @override
  String get routineDetailNoReward => 'Esta rutina no tiene recompensa';

  @override
  String get rewardInputHint => 'p. ej., 10 minutos de vídeos';

  @override
  String get todayRoutineReorderFailedTitle => 'No se pudo guardar el orden';

  @override
  String get todayRoutineReorderFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get todayRoutineDeleteConfirmTitle => '¿Borrar esta rutina?';

  @override
  String get todayRoutineStartedTitle => 'Elumi ya empezó esta rutina';

  @override
  String get todayRoutineStartedMessage =>
      'No se puede borrar para que lo hecho quede registrado';

  @override
  String get todayRoutineDeleteAction => 'Borrar';

  @override
  String get todayRoutineDeleteFailedTitle => 'No se pudo borrar la rutina';

  @override
  String get todayRoutineDeleteFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get todayRoutineLoadFailedFallback =>
      'No se pudieron cargar las rutinas';

  @override
  String get todayRoutineRerunFailedTitle => 'No se pudo repetir la rutina';

  @override
  String get todayRoutineRerunFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String todayRoutineCopied(String title, String batchim) {
    return 'Añadiste $title a las rutinas de hoy';
  }

  @override
  String get todayRoutinePastLoadFailedFallback =>
      'No se pudieron cargar las rutinas pasadas';

  @override
  String get todayRoutineEmptyTitle => 'Aún no hay rutinas';

  @override
  String get todayRoutineEmptyHint =>
      'Crea tus primeras tarjetas de acción de hoy';

  @override
  String get todayRoutinePastEmpty => 'No hay rutinas pasadas';

  @override
  String get homeCoachCreate => 'Puedes crear una *rutina nueva\npara Elumi*';

  @override
  String get homeCoachSwipe =>
      '*Desliza una rutina a la izquierda*\npara *editarla o borrarla*';

  @override
  String get homeCoachSwitch =>
      'Toca el icono del personaje\npara *cambiar al modo Elumi*';

  @override
  String childHomeGreeting(String name, String batchim) {
    return 'Esto es lo que $name\ntiene que hacer hoy. ¡Tú puedes!';
  }

  @override
  String childHomeEmptyTitle(String name, String batchim) {
    return 'Aún no hay rutinas\npara $name';
  }

  @override
  String get childHomeEmptyHint => 'Crea una rutina en el modo tutor';

  @override
  String get childHomeEmptyHintDevice =>
      'Crea una rutina en el dispositivo de un tutor';

  @override
  String get childHomeToGuardianLabel => 'Ir al modo tutor';

  @override
  String get childHomeSettingsLabel => 'Abrir ajustes';

  @override
  String get childHomeRewardPrefix => 'Al terminar:';

  @override
  String childStarsEarned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Conseguiste $count estrellas\n¡Sigue así y encuentra más estrellas!',
      one: 'Conseguiste $count estrella\n¡Sigue así y encuentra más estrellas!',
    );
    return '$_temp0';
  }

  @override
  String childStarsSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estrellas conseguidas',
      one: '$count estrella conseguida',
    );
    return '$_temp0';
  }

  @override
  String childCardPagerLabel(int total, int index) {
    return 'Tarjeta $index de $total';
  }

  @override
  String get childDetailSoundFailedTitle => 'No se pudo reproducir el sonido';

  @override
  String get childDetailSoundFailedFallback =>
      'Activa el sonido del dispositivo y toca otra vez';

  @override
  String get childDetailCheckLabel => '¡Lo hice!';

  @override
  String get rewardBannerPrefix => 'Al terminar: ';

  @override
  String get rewardLumiTitle => '¡Felicidades!';

  @override
  String rewardLumiMessage(String name) {
    return 'Lumi trajo una estrella para $name\npor hacerlo todo';
  }

  @override
  String get rewardLumiButton => '¡Bien!';

  @override
  String get rewardPopoTitle => '¡Muy bien!';

  @override
  String rewardPopoMessage(String name) {
    return 'Popo trajo a $name\nuna estrella grande de regalo';
  }

  @override
  String get rewardPopoButton => '¡Genial!';

  @override
  String get rewardRuruTitle => '¡Increíble!';

  @override
  String rewardRuruMessage(String name, String batchim) {
    return 'Ruru trajo un regalo\nporque $name lo hizo todo';
  }

  @override
  String get rewardRuruButton => '¡Hurra!';

  @override
  String get routineDoneTitle => '¡Rutina terminada!';

  @override
  String routineDoneMessage(String name) {
    return 'Preparado para $name,\nque lo terminó todo';
  }

  @override
  String get routineDoneButton => '¡Lo logré!';

  @override
  String get routineDoneRewardCaption => 'Recompensa de hoy';

  @override
  String get modeSwitchToChild =>
      'Escribe la contraseña para cambiar al modo Elumi';

  @override
  String get modeSwitchToGuardian =>
      'Escribe la contraseña para cambiar al modo tutor';

  @override
  String get modeSwitchTitle => 'Escribe tu contraseña';

  @override
  String get modeSwitchMismatch =>
      'La contraseña no coincide. Inténtalo de nuevo.';

  @override
  String get modeSwitchPinLabel => 'Escribir contraseña';

  @override
  String get pinForgotLink => 'Olvidé la contraseña';

  @override
  String get pinForgotTitle => '¿Olvidaste la contraseña?';

  @override
  String get pinForgotMessage =>
      'Vuelve a iniciar sesión con la cuenta de tutor\npara crear una contraseña nueva';

  @override
  String get pinForgotRelogin => 'Iniciar sesión de nuevo';

  @override
  String get modeSwitchReadFailedTitle => 'No se pudo comprobar la contraseña';

  @override
  String get modeSwitchReadFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get modeSwitchBlockedTitle => 'Ábrelo en\nel dispositivo de un tutor';

  @override
  String get modeSwitchBlockedDescription =>
      'El modo tutor no se puede abrir en este dispositivo';

  @override
  String get modeSwitchBlockedBack => 'Volver';

  @override
  String get installationRetryTitle => 'Algo salió mal';

  @override
  String get installationRetryMessage =>
      'No se pudo comprobar el inicio de sesión. Inténtalo de nuevo.';

  @override
  String get installationRetryButton => 'Reintentar';

  @override
  String get issuedCodeCopyButton => 'Copiar código';

  @override
  String get issuedCodeCopied => 'Código copiado';

  @override
  String get issuedCodeCopyFailedTitle => 'No se pudo copiar';

  @override
  String get issuedCodeCopyFailedFallback =>
      'Indica tú mismo el código que aparece en la pantalla';

  @override
  String linkShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '$minutes minuto',
    );
    return 'Vamos a conectar el dispositivo de Elumi. Toca el enlace de abajo en ese dispositivo para abrir la app elum con el código de conexión ya escrito.\nEl código de conexión sirve durante $_temp0.\n\n$url\n\nSi el enlace no se abre, escríbelo en la app.\nCódigo de conexión $code';
  }

  @override
  String get linkRejectedAlreadyLinked => 'Este dispositivo ya está conectado';

  @override
  String get linkRejectedOnGuardianPhone => 'Ábrelo en el dispositivo de Elumi';

  @override
  String get myCreditTitle => 'Mis créditos';

  @override
  String get planFreeBadge => 'FREE';

  @override
  String get myCreditKindPeriodicWeek => 'Semanal';

  @override
  String get myCreditKindPeriodicMonth => 'Mensual';

  @override
  String get myCreditKindBonus => 'Bonificación';

  @override
  String get myCreditKindPurchased => 'Comprados';

  @override
  String get myCreditSubscribeLabel => 'Si te suscribes';

  @override
  String get myCreditSubscribeBody =>
      'Dibuja imágenes con IA y envía rutinas automáticamente';

  @override
  String get myCreditPackLabelFree => 'Comprar solo créditos';

  @override
  String get myCreditPackLabelPro => 'Comprar más créditos';

  @override
  String get creditGetMore => 'Conseguir más créditos';

  @override
  String myCreditPackDiscount(int percent) {
    return '-$percent%';
  }

  @override
  String get myCreditPackPopular => '¡Popular!';

  @override
  String myCreditPackBuy(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Comprar $count créditos',
      one: 'Comprar $count crédito',
    );
    return '$_temp0 ($price)';
  }

  @override
  String get myCreditPackNoExpiryNote => 'Los créditos comprados no caducan';

  @override
  String get myCreditPackPriceFailed =>
      'No se pudieron cargar los precios de los créditos';

  @override
  String myCreditPackTileLabel(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count créditos',
      one: '$count crédito',
    );
    return '$_temp0, $price';
  }

  @override
  String get myCreditPurchaseRecheckTitle => 'Tus créditos aún no han llegado';

  @override
  String get myCreditPurchaseRecheckBody =>
      'El pago ya se hizo. Solo tienes que comprobarlo, no pagar otra vez';

  @override
  String get creditHistoryTitle => 'Historial de créditos';

  @override
  String get creditMineLink => 'Ver mis créditos';

  @override
  String creditHistoryDay(int month, int day) {
    return '$day/$month';
  }

  @override
  String creditHistoryDetail(String kind, String time) {
    return '$kind・$time';
  }

  @override
  String get creditHistoryKindRoutineText => 'Crear el texto de la rutina';

  @override
  String creditHistoryKindCardImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imágenes de tarjeta',
      one: '$count imagen de tarjeta',
    );
    return '$_temp0';
  }

  @override
  String get creditHistoryKindCardImage => 'Crear una imagen de tarjeta';

  @override
  String get creditHistoryKindImageRegenerate =>
      'Rehacer una imagen de tarjeta';

  @override
  String get creditHistoryFree => 'Sin usar créditos';

  @override
  String get creditHistoryKindWeeklyGrant =>
      'Recargamos tus créditos de esta semana';

  @override
  String get creditHistoryKindAdReward => 'Recibidos por ver un anuncio';

  @override
  String get creditHistoryKindAdminBonus =>
      'Una bonificación del equipo de elum';

  @override
  String get creditHistoryKindOtherGrant => 'Recibiste créditos';

  @override
  String get creditHistoryExpiredWeekTitle =>
      'Créditos de la semana pasada retirados';

  @override
  String get creditHistoryExpiredMonthTitle =>
      'Créditos del mes pasado retirados';

  @override
  String get creditHistoryExpiredWeekReason =>
      'Los créditos semanales que no usas no se acumulan';

  @override
  String get creditHistoryExpiredMonthReason =>
      'Los créditos mensuales que no usas no se acumulan';

  @override
  String get creditHistoryAdjustedTitle => 'Ajuste de créditos';

  @override
  String get creditHistoryAdjustedReason => 'Por un reembolso o un ajuste';

  @override
  String get creditHistoryKindUnknownSpend => 'Usaste créditos';

  @override
  String get creditHistoryEmptyTitle => 'Aún no has usado créditos';

  @override
  String get creditHistoryEmptyBody =>
      'Cuando crees una rutina, aparecerá aquí';

  @override
  String get creditHistoryLoadFailed =>
      'No se pudo cargar el historial de créditos';

  @override
  String get creditHistoryMoreFailed => 'No se pudo cargar más';

  @override
  String get reminderRowLabel => 'Recordatorio de rutina';

  @override
  String get reminderRowOff => 'Sin recordatorio';

  @override
  String reminderRowDaily(String time) {
    return 'Todos los días a las $time';
  }

  @override
  String reminderRowOnce(String time) {
    return 'Una vez a las $time';
  }

  @override
  String get reminderSheetTitle => '¿Cuándo te lo recordamos?';

  @override
  String get reminderSheetBody =>
      'Este dispositivo recibirá un aviso a la hora que elijas';

  @override
  String get reminderRepeatDaily => 'Avisar a la misma hora todos los días';

  @override
  String get reminderTurnOn => 'Activar recordatorio';

  @override
  String get reminderUpdate => 'Cambiar la hora del recordatorio';

  @override
  String get reminderTurnOff => 'Desactivar recordatorio';

  @override
  String get reminderSavedToast => 'Recordatorio listo';

  @override
  String get reminderClearedToast => 'Recordatorio desactivado';

  @override
  String get reminderPermissionDeniedTitle =>
      'Las notificaciones están desactivadas';

  @override
  String get reminderPermissionDeniedBody =>
      'Permite las notificaciones de elum en los ajustes del dispositivo para recibir recordatorios de rutinas';

  @override
  String get reminderFailedTitle => 'No se pudo poner el recordatorio';

  @override
  String get reminderFailedBody => 'Inténtalo de nuevo en un momento';

  @override
  String get reminderChannelName => 'Recordatorios de rutinas';

  @override
  String get reminderNotificationTitle => 'elum';

  @override
  String reminderNotificationBody(String routineTitle) {
    return 'Es hora de $routineTitle';
  }

  @override
  String get routineTemplateOpen => 'Ver rutinas de ejemplo';

  @override
  String get routineImageStylePillLabel => 'Imágenes de tarjetas';

  @override
  String routineImageStylePillSemantics(String style) {
    return 'Estilo de imagen de las tarjetas: $style. Toca para cambiarlo';
  }

  @override
  String get routineTemplateSheetTitle => 'Rutinas de ejemplo';

  @override
  String get routineTemplateSheetBody =>
      'Elige una y rellenamos el texto. Ajústalo para tu Elumi antes de enviarlo';

  @override
  String get routineTemplateBeginnerBadge => 'Ideal para empezar';

  @override
  String get routineTemplateCategorySelfCare => 'Cuidado personal';

  @override
  String get routineTemplateCategorySelfCareHint =>
      'Cosas de cada día, como lavarse, vestirse y comer';

  @override
  String get routineTemplateCategoryDailyFlow => 'Ritmo del día';

  @override
  String get routineTemplateCategoryDailyFlowHint =>
      'Los grandes pasos desde la mañana hasta la hora de dormir';

  @override
  String get routineTemplateCategoryHousehold => 'Tareas de casa';

  @override
  String get routineTemplateCategoryHouseholdHint =>
      'Ordenar sus propias cosas y su espacio';

  @override
  String get routineTemplateCategoryCommunity => 'Salir';

  @override
  String get routineTemplateCategoryCommunityHint =>
      'Practicar hacer cosas por su cuenta, como tomar el autobús o hacer compras';

  @override
  String get routineTemplateCategoryLearning => 'Estudio';

  @override
  String get routineTemplateCategoryLearningHint =>
      'Empezar y terminar el rato de estudio en orden';

  @override
  String get routineTemplateCategoryFeelings => 'Emociones y amigos';

  @override
  String get routineTemplateCategoryFeelingsHint =>
      'Expresar emociones, saludar y esperar su turno';

  @override
  String get routineTemplateBrushTeethText => 'Lavarse los dientes';

  @override
  String get routineTemplateBrushTeethPrompt =>
      'Quiero que mi Elumi se lave los dientes por su cuenta. Explica los pasos: sacar el cepillo y la pasta, llenar el vaso de agua, cepillarse, enjuagarse y guardar las cosas';

  @override
  String get routineTemplateWashFaceText => 'Lavarse la cara';

  @override
  String get routineTemplateWashFacePrompt =>
      'Quiero que mi Elumi se lave la cara por su cuenta por la mañana. Explica los pasos: abrir el grifo, mojarse la cara, hacer espuma con el jabón, enjuagarse, secarse con la toalla y ponerse crema';

  @override
  String get routineTemplateGetDressedText => 'Vestirse por su cuenta';

  @override
  String get routineTemplateGetDressedPrompt =>
      'Quiero que mi Elumi se vista por su cuenta. Explica los pasos: ponerse la camiseta interior, la camiseta, los pantalones y los calcetines, uno por uno';

  @override
  String get routineTemplateEatMealText => 'Hora de comer';

  @override
  String get routineTemplateEatMealPrompt =>
      'Quiero que mi Elumi coma por su cuenta. Explica los pasos: beber agua, traer su cuchara y su plato, sentarse a comer y llevar los platos de vuelta';

  @override
  String get routineTemplateBathTimeText => 'Hora del baño';

  @override
  String get routineTemplateBathTimePrompt =>
      'Quiero que mi Elumi se bañe paso a paso. Explica los pasos: quitarse la ropa, mojarse el cuerpo, lavarse el pelo, lavarse el cuerpo, enjuagarse, secarse con la toalla y vestirse';

  @override
  String get routineTemplateMorningRoutineText => 'Prepararse para la escuela';

  @override
  String get routineTemplateMorningRoutinePrompt =>
      'Quiero que mi Elumi haga en orden todo, desde despertarse hasta salir para la escuela. Explica los pasos: levantarse, ir al baño, comer, lavarse la cara y los dientes, vestirse, y ponerse la mochila y los zapatos';

  @override
  String get routineTemplateAfterSchoolText => 'Después de la escuela';

  @override
  String get routineTemplateAfterSchoolPrompt =>
      'Quiero que mi Elumi haga cosas por su cuenta al volver de la escuela. Explica los pasos: guardar los zapatos, lavarse las manos, dejar la mochila en su sitio, merendar y descansar';

  @override
  String get routineTemplateBedtimeText => 'Prepararse para dormir';

  @override
  String get routineTemplateBedtimePrompt =>
      'Quiero que mi Elumi siga en orden los pasos antes de dormir. Explica los pasos: lavarse los dientes, ponerse el pijama, preparar la mochila de mañana y apagar la luz para acostarse';

  @override
  String get routineTemplateGoingOutText => 'Prepararse para salir';

  @override
  String get routineTemplateGoingOutPrompt =>
      'Quiero que mi Elumi se prepare por su cuenta antes de salir. Explica los pasos: ir al baño, ponerse la chaqueta, llevar la botella de agua y el teléfono, ponerse los zapatos y esperar junto a la puerta';

  @override
  String get routineTemplateTidyRoomText => 'Ordenar la habitación';

  @override
  String get routineTemplateTidyRoomPrompt =>
      'Quiero que mi Elumi ordene su habitación después de jugar. Explica los pasos: juntar los juguetes, meterlos en la caja, poner los libros en la estantería y colgar la ropa';

  @override
  String get routineTemplateClearDishesText => 'Recoger los platos';

  @override
  String get routineTemplateClearDishesPrompt =>
      'Quiero que mi Elumi recoja sus platos después de comer. Explica los pasos: juntar las sobras, llevar los platos, dejarlos en el fregadero y limpiar la mesa';

  @override
  String get routineTemplateFoldLaundryText => 'Doblar la ropa';

  @override
  String get routineTemplateFoldLaundryPrompt =>
      'Quiero que mi Elumi doble y guarde la ropa seca. Explica los pasos: traer la ropa, emparejar los calcetines, doblar las toallas, doblar la ropa y guardarla en el cajón';

  @override
  String get routineTemplateTakeOutTrashText => 'Sacar la basura';

  @override
  String get routineTemplateTakeOutTrashPrompt =>
      'Quiero que mi Elumi separe y saque la basura. Explica los pasos: juntar la basura, separar el papel y el plástico, cerrar la bolsa y llevarla al lugar correcto';

  @override
  String get routineTemplateRideBusText => 'Tomar el autobús';

  @override
  String get routineTemplateRideBusPrompt =>
      'Quiero que mi Elumi practique tomar el autobús por su cuenta. Explica los pasos: mirar el número del autobús en la parada, hacer fila, pasar la tarjeta de transporte, sentarse y tocar el timbre en su parada';

  @override
  String get routineTemplateBuyItemText => 'Comprar algo en una tienda';

  @override
  String get routineTemplateBuyItemPrompt =>
      'Quiero que mi Elumi compre algo en una tienda por su cuenta. Explica los pasos: buscar el producto, hacer fila en la caja, dejar el producto, pagar con tarjeta o en efectivo, y tomar el recibo y dar las gracias';

  @override
  String get routineTemplateUseElevatorText => 'Subir en ascensor a un piso';

  @override
  String get routineTemplateUseElevatorPrompt =>
      'Quiero que mi Elumi suba en ascensor a un piso concreto por su cuenta. Explica los pasos: pulsar el botón, entrar cuando se abra la puerta, pulsar el número del piso, mirar el indicador de piso y salir';

  @override
  String get routineTemplateHospitalVisitText => 'Ir al médico';

  @override
  String get routineTemplateHospitalVisitPrompt =>
      'Quiero que mi Elumi haga en orden una visita al médico. Explica los pasos: registrarse en recepción, esperar en la sala de espera, entrar cuando lo llamen, ver al médico, y recoger la medicina y despedirse';

  @override
  String get routineTemplateStartHomeworkText => 'Empezar los deberes';

  @override
  String get routineTemplateStartHomeworkPrompt =>
      'Quiero que mi Elumi empiece y termine los deberes por su cuenta. Explica los pasos: sentarse en el escritorio, sacar el cuaderno y el lápiz, hacer los deberes, enseñarlos al terminar y guardarlos en la mochila';

  @override
  String get routineTemplateWriteNameText => 'Practicar escribir su nombre';

  @override
  String get routineTemplateWriteNamePrompt =>
      'Quiero que mi Elumi tome bien el lápiz y escriba su nombre. Explica los pasos: tomar el lápiz, colocar el papel, repasar el nombre, escribirlo por su cuenta y recoger';

  @override
  String get routineTemplateCountObjectsText => 'Juego de contar';

  @override
  String get routineTemplateCountObjectsPrompt =>
      'Quiero que mi Elumi practique contar objetos uno por uno. Explica los pasos: poner los objetos en fila, señalar cada uno con el dedo, contar en voz alta y decir el total';

  @override
  String get routineTemplateReadBookText => 'Hora de leer';

  @override
  String get routineTemplateReadBookPrompt =>
      'Quiero que mi Elumi tenga su rato de lectura por su cuenta. Explica los pasos: elegir un libro, sentarse, pasar las páginas una por una y devolver el libro a la estantería';

  @override
  String get routineTemplateEmotionCardText =>
      'Mostrar una tarjeta de emociones al enfadarse';

  @override
  String get routineTemplateEmotionCardPrompt =>
      'Cuando mi Elumi se enfada con un amigo, quiero que muestre una tarjeta de emociones en vez de gritar o empujar. Explica los pasos: detenerse, sacar la tarjeta de emociones del bolsillo, elegir la tarjeta de cómo se siente y mostrársela al profesor';

  @override
  String get routineTemplatePlayNicelyText => 'Jugar bien con los amigos';

  @override
  String get routineTemplatePlayNicelyPrompt =>
      'Quiero que mi Elumi practique jugar bien con sus amigos. Explica los pasos: pedir jugar juntos, compartir los juguetes, turnarse y dar las gracias al final';

  @override
  String get routineTemplateGreetingText => 'Saludar';

  @override
  String get routineTemplateGreetingPrompt =>
      'Quiero que mi Elumi salude primero. Explica los pasos: mirar a la cara de la persona, mover la mano, decir hola y sonreír';

  @override
  String get routineTemplateWaitTurnText => 'Esperar su turno';

  @override
  String get routineTemplateWaitTurnPrompt =>
      'Quiero que mi Elumi practique esperar su turno en la fila. Explica los pasos: ponerse al final de la fila, esperar detrás de la persona de delante, fijarse en cuándo le toca y avanzar cuando llegue su turno';

  @override
  String get routineTemplateAskHelpText => 'Pedir ayuda';

  @override
  String get routineTemplateAskHelpPrompt =>
      'Quiero que mi Elumi pida ayuda cuando algo le cueste. Explica los pasos: detenerse, buscar a un adulto cerca, decir \'ayúdame, por favor\' y dar las gracias después de recibir ayuda';

  @override
  String get guardianTabHome => 'Inicio';

  @override
  String get guardianTabManage => 'Rutinas';

  @override
  String get guardianTabTalk => 'Historias';

  @override
  String get guardianTabMe => 'Mi información';

  @override
  String get guardianMyInfoProfileName => 'Tutor';

  @override
  String get guardianMyInfoEmailPrivate => 'Correo privado';

  @override
  String guardianMyInfoJoinedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'y. MM. dd',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return 'Te uniste el $dateString';
  }

  @override
  String get guardianMyInfoActiveBadge => 'Viendo';

  @override
  String get guardianNicknameEditLabel => 'Cambiar apodo';

  @override
  String get guardianNicknameSheetTitle => 'Cambiar mi nombre';

  @override
  String get guardianNicknameSheetDescription =>
      'Es el nombre que se ve cuando escribes en Historias.\nPuedes cambiarlo una vez cada 7 días';

  @override
  String get guardianNicknameSheetHint => 'Escribe un nombre';

  @override
  String get guardianNicknameSheetSave => 'Guardar';

  @override
  String get guardianNicknameInvalidFormat =>
      'Usa de 2 a 16 letras coreanas o inglesas, números o guiones';

  @override
  String guardianNicknameChangeableFrom(String since) {
    return '$since podrás cambiarlo';
  }

  @override
  String get guardianNicknameChanged => 'Cambiaste tu apodo';

  @override
  String get guardianNicknameSaveFailed => 'No se pudo cambiar tu apodo';

  @override
  String get guardianSideNavCaption => 'Modo tutor';

  @override
  String get guardianSideNavChildScreen => 'Modo Elumi';

  @override
  String get routineLibraryEmptyTitle => 'Aún no hay rutinas';

  @override
  String get routineLibraryEmptyBody =>
      'Toca + Nueva rutina abajo para crear la primera';

  @override
  String get routineLibraryLoadFailedFallback =>
      'No se pudieron cargar tus rutinas';

  @override
  String get routineLibraryCreate => 'Nueva rutina';

  @override
  String get routineLibrarySendToday => 'Enviar hoy';

  @override
  String get routineLibraryEditCards => 'Editar tarjetas';

  @override
  String get routineLibraryAlreadySent => 'Ya se envió hoy';

  @override
  String get routineLibrarySendFailedTitle => 'No se pudo enviar';

  @override
  String get routineLibraryActionFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get routineLibraryCopied => 'Se creó una copia';

  @override
  String get routineLibraryCopyFailedTitle => 'No se pudo copiar';

  @override
  String get routineLibraryMenuRename => 'Cambiar nombre';

  @override
  String get routineLibraryMenuCopy => 'Copiar';

  @override
  String get routineLibraryMenuRemove => 'Eliminar';

  @override
  String get routineLibraryRenameHint => 'Nombre de la rutina';

  @override
  String get routineLibraryRenameSave => 'Guardar';

  @override
  String get routineLibraryRenamed => 'Cambiaste el nombre';

  @override
  String get routineLibraryRenameFailedTitle => 'No se pudo cambiar el nombre';

  @override
  String get routineLibraryRemoveConfirmTitle => '¿Eliminar esta rutina?';

  @override
  String get routineLibraryRemoveConfirmMessage =>
      'Sale de tu lista de rutinas. Lo que tu Elumi ya hizo queda guardado';

  @override
  String get routineLibraryRemoved => 'Eliminaste la rutina';

  @override
  String get routineLibraryRemoveFailedTitle => 'No se pudo eliminar';

  @override
  String get routineLibrarySentBadge => 'Enviada hoy';

  @override
  String get routineLibraryTileHint => 'Mantén pulsado para abrir el menú';

  @override
  String get routineLibraryFromTalk => 'De Historias';

  @override
  String get routineLibraryNewBadge => 'Nueva';

  @override
  String get routineDetailTalkOriginBand => 'Traído de Historias';

  @override
  String get routineDetailTalkOriginOpenPost => 'Publicación original';

  @override
  String get routineDetailTalkOriginPostGone => 'Publicación retirada';

  @override
  String get routineDetailTalkOriginBandOpenLabel =>
      'Traído de Historias, ver la publicación original';

  @override
  String routineLibrarySent(String title, String batchim) {
    return 'Enviaste $title como rutina de hoy';
  }

  @override
  String onboardingExampleTitle(String name, String batchim) {
    return '¿En qué te gustaría\nayudar a $name?';
  }

  @override
  String get onboardingExampleDescription =>
      'Añadiremos rutinas de ejemplo de lo que elijas.\nPuedes elegir más de una.';

  @override
  String get onboardingExampleSkip => 'Omitir';

  @override
  String get exampleCategoryMorningEvening => 'Mañana y noche';

  @override
  String get exampleCategoryMorningEveningHint =>
      'Asearse, vestirse, ir a dormir';

  @override
  String get exampleCategorySchoolStudy => 'Escuela y estudio';

  @override
  String get exampleCategorySchoolStudyHint =>
      'Prepararse para la escuela, deberes';

  @override
  String get exampleCategoryHouseSelf => 'Tareas y hacerlo solo';

  @override
  String get exampleCategoryHouseSelfHint => 'Ordenar, poner la mesa';

  @override
  String get exampleCategoryOutside => 'Salir y probar';

  @override
  String get exampleCategoryOutsideHint => 'Tomar el autobús, hacer compras';

  @override
  String get exampleRoutinesFailed =>
      'No se pudieron añadir las rutinas de ejemplo';

  @override
  String get routineGroupMenuAddToGroup => 'Añadir a un grupo';

  @override
  String get routineGroupMenuReorder => 'Cambiar el orden';

  @override
  String get routineGroupMenuUngroup => 'Deshacer el grupo';

  @override
  String routineGroupTileLabel(String name, int count) {
    return 'Grupo $name, $count rutinas';
  }

  @override
  String get routineGroupDefaultName => 'Nuevo grupo';

  @override
  String get routineGroupNameLabel => 'Nombre del grupo';

  @override
  String get routineGroupNameHint => 'Nombre del grupo (p. ej., Mañana)';

  @override
  String get routineGroupNewTitle => 'Nuevo grupo';

  @override
  String routineGroupAddTitle(String name) {
    return 'Añadir a $name';
  }

  @override
  String get routineGroupPickHintNew =>
      'Toca las rutinas en el orden en que quieres mostrarlas';

  @override
  String get routineGroupPickHint => 'Toca las rutinas en orden';

  @override
  String get routineGroupPickEmpty => 'No hay rutinas para añadir';

  @override
  String routineGroupPickConfirmNew(int count) {
    return 'Agrupar $count';
  }

  @override
  String routineGroupPickConfirmAdd(int count) {
    return 'Añadir $count';
  }

  @override
  String get routineGroupCreateMenuTitle => '¿Qué quieres crear?';

  @override
  String get routineGroupCreateRoutine => 'Nueva rutina';

  @override
  String get routineGroupCreateGroup => 'Nuevo grupo';

  @override
  String get routineGroupCreateGroupDescription =>
      'Junta varias rutinas en una carpeta (p. ej., Mañana de escuela)';

  @override
  String get routineGroupChooseTitle => '¿En qué grupo?';

  @override
  String routineGroupSheetCount(int count) {
    return '$count rutinas';
  }

  @override
  String get routineGroupSheetAdd => 'Añadir rutinas';

  @override
  String routineGroupSheetRemove(String title) {
    return 'Sacar $title del grupo';
  }

  @override
  String get routineGroupCreated => 'Creaste el grupo';

  @override
  String get routineGroupAdded => 'Añadida al grupo';

  @override
  String get routineGroupUngrouped => 'Deshiciste el grupo';

  @override
  String get routineGroupUngroupedEmpty =>
      'Sacaste todas las rutinas, así que el grupo se deshizo';

  @override
  String routineGroupSent(String name) {
    return 'Enviaste el grupo $name como rutina de hoy';
  }

  @override
  String get routineGroupAllSentAlready =>
      'Todo lo de este grupo ya se envió hoy';

  @override
  String get routineGroupActionFailedTitle => 'No se pudo cambiar el grupo';

  @override
  String get routineGroupUngroupConfirmTitle => '¿Deshacer este grupo?';

  @override
  String get routineGroupUngroupConfirmMessage =>
      'Las rutinas se quedan en Rutinas';

  @override
  String routineGroupRemoveConfirmTitle(String title) {
    return '¿Sacar $title del grupo?';
  }

  @override
  String get routineGroupRemoveConfirmMessage =>
      'La rutina se queda en Rutinas';

  @override
  String get routineGroupRemoveConfirmAction => 'Sacar';

  @override
  String childHomeGroupProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String get childHomeGroupAllDone => '¡Todo listo!';

  @override
  String get routineTitleEdit => 'Cambiar el nombre de la rutina';

  @override
  String get routineDetailMore => 'Más';

  @override
  String get libraryArrangeDone => 'Listo';

  @override
  String get libraryArrangeRemove => 'Sacar o deshacer el grupo';

  @override
  String get routineGroupEditOrder => 'Editar';

  @override
  String get routineLibrarySendOnlyThis => 'Enviar solo esta hoy';

  @override
  String routineGroupRowCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarjetas',
      one: '$count tarjeta',
    );
    return '$_temp0';
  }

  @override
  String get routineManageCoachTapMessage =>
      '*Toca* una rutina para ver sus tarjetas';

  @override
  String get routineManageCoachLongPressMessage =>
      'Mantén pulsado y *suelta* para abrir el menú';

  @override
  String get routineManageCoachDragMessage =>
      'Mantén pulsado y *mueve* para ordenar\nSuéltala sobre otra rutina para hacer un *grupo*\nSuéltala entre dos para cambiarla de lugar';

  @override
  String get cardReviewCoachEditMessage =>
      'Cambia el *texto y la imagen* de esta tarjeta\nTambién puedes usar *tu propia foto*';

  @override
  String get cardReviewCoachReorderMessage =>
      'Toca aquí y luego *mantén pulsada y arrastra* una tarjeta\npara cambiar el orden';

  @override
  String get cardReviewCoachSaveMessage =>
      'Cuando termines, toca *Guardar tarjetas*\nLa rutina queda lista solo al guardar';

  @override
  String get coachHelpLabel => 'Cómo se usa';

  @override
  String get pushPermissionSheetTitle =>
      '¿Quieres que te avisemos cuando Elumi termine una rutina?';

  @override
  String get pushPermissionSheetBody =>
      'También recibirás novedades de otros tutores y avisos de créditos';

  @override
  String get pushPermissionAllow => 'Activar';

  @override
  String get pushPermissionLater => 'Ahora no';

  @override
  String get pushPermissionDenied =>
      'Puedes activarlo cuando quieras en los ajustes de notificaciones';

  @override
  String get pushChannelGuardianUpdates => 'Novedades para tutores';

  @override
  String get pushPermissionNudgeTitle =>
      'Las notificaciones están desactivadas';

  @override
  String get pushPermissionNudgeBody =>
      'Actívalas para saber al momento cuando Elumi termine una rutina';

  @override
  String get pushPermissionElumiTitle =>
      '¿Quieres un aviso cuando llegue una rutina nueva?';

  @override
  String get pushPermissionElumiBody =>
      'Recibirás una notificación en este dispositivo cuando un tutor envíe una rutina';

  @override
  String get pushPermissionTurnOn => 'Activar notificaciones';

  @override
  String get pushChannelElumiRoutines => 'Rutinas nuevas';

  @override
  String get signInProviderKakao => 'Kakao';

  @override
  String get signInProviderNaver => 'Naver';

  @override
  String get signInProviderGoogle => 'Google';

  @override
  String get signInProviderApple => 'Apple';

  @override
  String get routineManageCoachSampleMorning => 'Preparar la mañana';

  @override
  String get routineManageCoachSampleBrush => 'Lavarse los dientes';

  @override
  String get routineManageCoachSampleBag => 'Preparar la mochila';

  @override
  String get updateSuggestionTitle => 'Hay una nueva versión';

  @override
  String get updateSuggestionBody =>
      'Actualiza para usar las últimas mejoras y funciones';

  @override
  String get updateSuggestionLater => 'Más tarde';

  @override
  String elumiInfoTitle(String name) {
    return 'Información de $name';
  }

  @override
  String elumiInfoEditLabel(String name) {
    return 'Editar la información de $name';
  }

  @override
  String get elumiInfoName => 'Nombre';

  @override
  String get elumiInfoCharacter => 'Personaje';

  @override
  String get elumiInfoCharacterSheetTitle => 'Cambiar personaje';

  @override
  String get elumiInfoImageStyleSheetTitle => 'Cambiar el estilo de imagen';

  @override
  String get elumiInfoSave => 'Guardar';

  @override
  String get elumiInfoSaved => 'Guardado';

  @override
  String get elumiInfoSaveFailedTitle => 'No se pudo guardar';

  @override
  String get elumiInfoSaveFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get elumiInfoNotFound => 'No se pudo cargar la información de Elumi';

  @override
  String get talkTitle => 'Historias';

  @override
  String get talkWriteButton => 'Publicar';

  @override
  String get talkCategoryAll => 'Todo';

  @override
  String get talkPopularTitle => 'Rutinas más llevadas esta semana';

  @override
  String talkPopularImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count se la llevaron',
      one: '$count se la llevó',
    );
    return '$_temp0';
  }

  @override
  String get talkLatestTitle => 'Recién publicadas';

  @override
  String get talkEmptyTitle => 'Aún no hay rutinas compartidas';

  @override
  String get talkEmptyCategoryTitle =>
      'Aún no hay rutinas compartidas en esta categoría';

  @override
  String get talkEmptyCategoryAction => 'Ver todo';

  @override
  String get talkFeedFailed => 'No se pudo cargar Historias';

  @override
  String get talkAuthorFallback => 'Tutor';

  @override
  String get talkShareTitleLabel => 'Título de la rutina';

  @override
  String get talkShareTitleHint => 'Escribe el título de la rutina';

  @override
  String get talkNoteLabel => 'Contenido';

  @override
  String talkHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Útil $count',
    );
    return '$_temp0';
  }

  @override
  String talkCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Comentarios $count',
      one: 'Comentario $count',
    );
    return '$_temp0';
  }

  @override
  String get talkLoadMoreRetry =>
      'No se pudo cargar más. Toca para intentarlo de nuevo';

  @override
  String talkDetailStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarjetas',
      one: '$count tarjeta',
    );
    return '$_temp0';
  }

  @override
  String get talkDetailLoadFailed => 'No se pudo cargar la publicación';

  @override
  String get talkPostGoneTitle => 'Esta publicación ya no está disponible';

  @override
  String get talkPostGoneBack => 'Volver a Historias';

  @override
  String talkDetailCardCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
    );
    return '$_temp0';
  }

  @override
  String talkDetailPostedAt(DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('M/d', localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dateString $timeString';
  }

  @override
  String get talkViewGrid => 'Ver todo junto';

  @override
  String get talkViewLarge => 'Ver en grande';

  @override
  String get talkHelpfulFailed =>
      'No se pudo cambiar Útil. Inténtalo de nuevo en un momento';

  @override
  String get talkImportButton => 'Llevar a mis rutinas';

  @override
  String get talkImportedButton => '✓ Añadida a Rutinas';

  @override
  String get talkShareLinkButton => 'Compartir';

  @override
  String talkShareLinkMessage(String title, String url) {
    return '$title\nVamos a verlo juntos en Historias de elum\n\n$url';
  }

  @override
  String get talkShareLinkFailed =>
      'No se pudo compartir. Inténtalo de nuevo en un momento';

  @override
  String get talkPostLinkRejectedOnElumiDevice =>
      'Las publicaciones de Historias se ven en el dispositivo del tutor';

  @override
  String get talkImportSheetTitle => 'Llevar a mis rutinas';

  @override
  String get talkImportSheetHint =>
      'Después de añadirla, puedes ajustarla para tu Elumi';

  @override
  String get talkImportElumiLabel => 'Elumi';

  @override
  String get talkImportConfirm => 'Listo';

  @override
  String get talkImportNoElumiTitle => 'Conecta primero a tu Elumi';

  @override
  String get talkImportNoElumiAction => 'Conectar a Elumi';

  @override
  String talkImportDone(String routineTitle, String batchim) {
    return 'Se importó $routineTitle';
  }

  @override
  String get talkImportGoToLibrary => 'Ver';

  @override
  String get talkImportFailedTitle => 'No se pudo añadir a Rutinas';

  @override
  String get talkCommentsTitle => 'Comentarios';

  @override
  String get talkCommentsEmpty => 'Aún no hay comentarios';

  @override
  String talkCommentAuthorMine(String name) {
    return '$name (yo)';
  }

  @override
  String talkCommentAuthorPostWriter(String name) {
    return '$name (autor)';
  }

  @override
  String get talkCommentHiddenNotice => 'Se ocultó según nuestras normas';

  @override
  String get talkCommentsFailed => 'No se pudieron cargar los comentarios';

  @override
  String get talkCommentHint => 'Deja un comentario';

  @override
  String get talkCommentSend => 'Enviar';

  @override
  String get talkCommentSendFailedTitle => 'No se pudo enviar el comentario';

  @override
  String get talkFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get talkCommentDeleteTitle => '¿Borrar el comentario?';

  @override
  String get talkCommentDeleteAction => 'Borrar';

  @override
  String get talkCommentDeleteFailedTitle => 'No se pudo borrar el comentario';

  @override
  String get talkMenuReport => 'Denunciar';

  @override
  String get talkMenuBlock => 'Ocultar las publicaciones de este tutor';

  @override
  String get talkMenuEdit => 'Editar';

  @override
  String get talkMenuTakeDown => 'Retirar';

  @override
  String get talkMoreLabel => 'Más';

  @override
  String get talkTakeDownTitle => '¿Retirar esta publicación?';

  @override
  String get talkTakeDownMessage =>
      'Cuando la retires, los demás tutores ya no la verán.';

  @override
  String get talkTakeDownDone => 'Retiraste la publicación';

  @override
  String get talkTakeDownFailedTitle => 'No se pudo retirar la publicación';

  @override
  String get talkEditTitle => 'Editar publicación';

  @override
  String get talkEditSave => 'Guardar';

  @override
  String get talkEditSaved => 'Editado';

  @override
  String get talkEditFailedTitle => 'No se pudo editar la publicación';

  @override
  String get talkNoteGuide =>
      'No escribas datos personales, como nombres o contactos de otras personas';

  @override
  String get talkCategoryTitle => 'Categoría';

  @override
  String get talkReportTitle => 'Denunciar';

  @override
  String get talkReportSubmit => 'Denunciar';

  @override
  String get talkReportDone => 'Denuncia enviada';

  @override
  String get talkReportFailedTitle => 'No se pudo denunciar';

  @override
  String get talkReportReasonPersonalInfo =>
      'Se ven datos de Elumi o de la familia';

  @override
  String get talkReportReasonOffensive => 'Tiene palabras ofensivas';

  @override
  String get talkReportReasonAdvertising => 'Es publicidad o promoción';

  @override
  String get talkReportReasonOther => 'Otro motivo';

  @override
  String talkBlockTitle(String nickname) {
    return '¿Ocultar las publicaciones de $nickname?';
  }

  @override
  String get talkBlockMessage =>
      'No verás las publicaciones ni los comentarios de este tutor. Esa persona no lo sabrá. Puedes volver a verlos en Mi información › Tutores ocultos.';

  @override
  String get talkBlockAction => 'Ocultar';

  @override
  String get talkBlockDone => 'Ocultado';

  @override
  String get talkBlockFailedTitle => 'No se pudo ocultar';

  @override
  String get talkBlockedGuardiansTitle => 'Tutores ocultos';

  @override
  String get talkBlockedGuardiansEmpty => 'No hay tutores ocultos';

  @override
  String get talkBlockedGuardiansFailed =>
      'No se pudieron cargar los tutores ocultos';

  @override
  String get talkUnblockAction => 'Volver a ver';

  @override
  String get talkUnblockDone => 'Ya puedes volver a verlos';

  @override
  String get talkUnblockFailedTitle => 'No se pudo dejar de ocultar';

  @override
  String get talkRulesTitle => 'Normas de Historias';

  @override
  String get talkRulesIntro =>
      'Para compartir de forma segura entre tutores, sigue estas tres normas.';

  @override
  String get talkRulesPrivacy =>
      'No muestres caras, nombres, escuelas ni direcciones de casa';

  @override
  String get talkRulesRespect =>
      'Respeta a los demás tutores. No se permiten críticas, anuncios ni promociones';

  @override
  String get talkRulesNoDiagnosis =>
      'No escribas diagnósticos ni datos de hospitales';

  @override
  String get talkRulesAgreeCheck => 'Leí las normas de arriba y las cumpliré';

  @override
  String get talkRulesAgreeButton => 'Aceptar y continuar';

  @override
  String get talkRulesFailedTitle => 'No se pudo guardar tu aceptación';

  @override
  String get talkShareTitle => 'Publicar en Historias';

  @override
  String get talkSharePickTitle => '¿Qué rutina quieres compartir?';

  @override
  String get talkSharePickEmpty => 'No hay rutinas para publicar';

  @override
  String get talkSharePickEmptyHint =>
      'Solo puedes publicar tus propias rutinas de Rutinas. Las que ya publicaste o te llevaste de Historias no aparecen. Puedes publicar una rutina de ejemplo después de cambiar su título o sus tarjetas.';

  @override
  String get talkSharePickFailed => 'No se pudieron cargar las rutinas';

  @override
  String get talkSharePreviewFailed =>
      'No se pudo cargar lo que vas a publicar';

  @override
  String get talkSharePhotoTitle => '¿Cómo quieres publicar las fotos?';

  @override
  String get talkSharePhotoGuide =>
      'Difumina caras, nombres y direcciones de casa si se ven.\nLas imágenes hechas con IA se publican tal cual';

  @override
  String get talkSharePhotoBlur => 'Difuminar';

  @override
  String get talkSharePhotoKeep => 'Tal cual';

  @override
  String get talkSharePhotoNext => 'Siguiente';

  @override
  String get talkSharePreviewTitle => 'Así se verá';

  @override
  String get talkShareSubmit => 'Publicar';

  @override
  String get talkShareDone => 'Publicaste en Historias';

  @override
  String get talkShareFailedTitle => 'No se pudo publicar';

  @override
  String get talkShareHint => '📖 Compártela en Historias ›';

  @override
  String get talkMenuShare => 'Compartir en Historias';

  @override
  String get talkMyPostsTitle => 'Mis publicaciones';

  @override
  String get talkMyPostsEmpty => 'Aún no tienes publicaciones';

  @override
  String get talkMyPostsEmptyAction => 'Comparte una rutina en Historias';

  @override
  String get talkMyPostsFailed => 'No se pudieron cargar tus publicaciones';

  @override
  String get talkMenuViewMyPost => 'Ver mi publicación';

  @override
  String get talkLinkSend => 'Enviar por enlace';

  @override
  String get talkLinkTurnOff => 'Desactivar enlace';

  @override
  String get talkLinkConfirmTitle => '¿Enviar esta rutina por enlace?';

  @override
  String get talkLinkConfirmGuide =>
      'Solo quien reciba el enlace podrá verlo. No se publica en Historias.\nPuedes desactivar el enlace en Rutinas cuando quieras';

  @override
  String get talkLinkResendGuide =>
      'Ya enviaste un enlace. Se vuelve a enviar el mismo enlace, tal como estaba la primera vez.\nPara enviar los cambios, desactiva el enlace y vuelve a enviarlo';

  @override
  String get talkLinkPhotoTitle => '¿Cómo quieres enviar las fotos?';

  @override
  String get talkLinkPhotoGuide =>
      'Difumina las fotos donde se vean caras, nombres o direcciones.\nLas imágenes hechas con IA se muestran tal cual';

  @override
  String get talkLinkCreateButton => 'Crear enlace';

  @override
  String get talkLinkPreviewFailed => 'No se pudo cargar lo que vas a enviar';

  @override
  String get talkLinkCreateFailedTitle => 'No se pudo crear el enlace';

  @override
  String get talkLinkCreated => 'Enlace creado';

  @override
  String talkLinkShareMessage(String title, String url) {
    return '$title\nLlévate esta rutina a tu elum\n\n$url';
  }

  @override
  String get talkLinkTurnOffTitle => '¿Desactivar el enlace?';

  @override
  String get talkLinkTurnOffMessage =>
      'Quien tenga el enlace ya no podrá verlo. Las rutinas que ya se llevaron se mantienen';

  @override
  String get talkLinkTurnOffDone => 'Enlace desactivado';

  @override
  String get talkLinkTurnOffFailedTitle => 'No se pudo desactivar el enlace';

  @override
  String get talkLinkReceivedTitle => 'Rutina recibida';

  @override
  String get timeAgoJustNow => 'Ahora mismo';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count minutos',
      one: 'hace $count minuto',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace $count hora',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace $count día',
    );
    return '$_temp0';
  }

  @override
  String routineProgressRingPercentLabel(int percent) {
    return '$percent% hecho';
  }

  @override
  String get routineProgressRingDoneLabel => 'Todo hecho';

  @override
  String get guardianSettingsLicenses => 'Licencias de código abierto';

  @override
  String get licenseScreenTitle => 'Licencias de código abierto';

  @override
  String get licenseScreenGuide =>
      'elum está hecha con las ilustraciones, fuentes y programas de abajo. Toca un elemento para leer su licencia completa.';

  @override
  String get licenseGroupArtwork => 'Ilustraciones';

  @override
  String get licenseGroupFonts => 'Fuentes';

  @override
  String get licenseGroupSoftware => 'Software';

  @override
  String get licenseSoftwareListRow => 'Ver la lista de software';

  @override
  String get licenseFontTmoneyName => 'Tmoney RoundWind';

  @override
  String get licenseLoadFailedMessage => 'No se pudo cargar la lista';

  @override
  String get cardExportOpen => 'Guardar para imprimir';

  @override
  String get cardExportFormatSection => '¿Cómo lo quieres?';

  @override
  String get cardExportFormatRoutineSheet => 'Rutina en una página';

  @override
  String get cardExportFormatRoutineSheetCaption => 'En orden, en una hoja A4';

  @override
  String get cardExportFormatCutCards => 'Tarjetas para recortar';

  @override
  String get cardExportFormatCutCardsCaption => 'En A4 con líneas de corte';

  @override
  String get cardExportFormatCardImages => 'Una tarjeta cada vez';

  @override
  String get cardExportFormatCardImagesCaption => 'Una imagen por tarjeta';

  @override
  String get cardExportPerPageSection => '¿Cuántas tarjetas por página?';

  @override
  String get cardExportIncludeText => 'Incluir el texto de la tarjeta';

  @override
  String get cardExportThemeSection => 'Diseño de la tarjeta';

  @override
  String get cardExportThemeBasic => 'Básico';

  @override
  String get cardExportThemeSimple => 'Sencillo';

  @override
  String get cardExportThemeInkSaver => 'Ahorro de tinta';

  @override
  String get cardExportThemeMonochrome => 'Blanco y negro';

  @override
  String get cardExportThemeLargeText => 'Texto grande';

  @override
  String get planProBadge => 'PRO';

  @override
  String get cardExportProThemeLocked => 'Este diseño está disponible con Pro';

  @override
  String get cardExportWatermarkNotice =>
      'Con Free se añade una franja con el logo de elum abajo';

  @override
  String get cardExportPreviewSection => 'Vista previa';

  @override
  String get cardExportMissingPicture =>
      'Las tarjetas sin imagen muestran solo el título';

  @override
  String cardExportSomePicturesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tarjetas cuyas imágenes no se pudieron cargar usarán otras imágenes o sus títulos',
      one:
          '$count tarjeta cuya imagen no se pudo cargar usará otra imagen o su título',
    );
    return '$_temp0';
  }

  @override
  String get cardExportActualSizeHint =>
      'Si imprimes desde otra app, elige el tamaño real';

  @override
  String get cardExportPrint => 'Imprimir';

  @override
  String get cardExportShare => 'Enviar';

  @override
  String get cardExportPreparing => 'Preparando tus tarjetas';

  @override
  String get cardExportImageFailed =>
      'No se pudo cargar la imagen de la tarjeta';

  @override
  String get cardExportRenderFailed =>
      'No se pudo crear el archivo para imprimir';

  @override
  String get cardExportPrintFailed =>
      'Este dispositivo no puede imprimir. Usa Enviar';

  @override
  String get cardExportNoCards => 'Esta rutina no tiene tarjetas';

  @override
  String get cardExportNoneSelected => 'Elige al menos una tarjeta para enviar';

  @override
  String get printBrandTagline =>
      'Cada día, juntos | Tarjetas de acción de elum';

  @override
  String get cardExportPictogramCredit =>
      'Imágenes: Mulberry Symbols (CC BY-SA 4.0)';

  @override
  String get cardExportEmojiCredit => 'Imágenes: Twemoji (CC BY 4.0)';

  @override
  String cardExportPerPage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarjetas',
      one: '$count tarjeta',
    );
    return '$_temp0';
  }

  @override
  String get cardExportFormatRow => 'Formato';

  @override
  String get cardExportLayoutSection => 'Diseño de página';

  @override
  String get cardExportStyleSection => 'Estilo';

  @override
  String get cardExportOrientationRow => 'Orientación del papel';

  @override
  String get cardExportOrientationSheetTitle =>
      '¿Cómo quieres colocar el papel?';

  @override
  String get cardExportOrientationPortrait => 'Vertical';

  @override
  String get cardExportOrientationLandscape => 'Horizontal';

  @override
  String get cardExportPerPageRow => 'Por página';

  @override
  String get cardExportCardSizeRow => 'Tamaño de la tarjeta';

  @override
  String get cardExportCardSizeSheetTitle =>
      '¿De qué tamaño quieres las tarjetas?';

  @override
  String get cardExportCardSizeFit => 'Llenar la página';

  @override
  String get cardExportCardSizeMedium => 'Mediano';

  @override
  String get cardExportCardSizeSmall => 'Pequeño';

  @override
  String get cardExportProLayoutLocked =>
      'Este formato está disponible con Pro';

  @override
  String get cardExportUpsellTitle => 'Con Pro, guárdalo a tu manera';

  @override
  String get cardExportUpsellBody =>
      'Elige una rutina en una página, tarjetas para recortar, varias tarjetas por página, papel horizontal y diseños';

  @override
  String get modeSwitchToPurchase => 'Solo un tutor puede hacer compras';

  @override
  String get planBenefitAiImageStyles =>
      'La IA dibuja una imagen para cada tarjeta';

  @override
  String get planBenefitAdsRemoved => 'Úsala sin anuncios';

  @override
  String get planBenefitWeeklyReport => 'Recibe un informe semanal';

  @override
  String get planBenefitRoutineSchedule =>
      'Elige días y horas y envíala cada día';

  @override
  String get planBenefitRoutineMemory => 'Recuerda cómo editas las cosas';

  @override
  String get planBenefitGuardianVoice =>
      'Lee las tarjetas en voz alta con tu propia voz';

  @override
  String get planBenefitFreeRoutineText =>
      'El texto de las rutinas no gasta créditos';

  @override
  String get planBenefitFreeImageRegenerate =>
      'Vuelve a dibujar imágenes sin créditos, algunas veces al día';

  @override
  String planBenefitFreeImageRegenerateDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vuelve a dibujar sin créditos hasta $count veces al día',
      one: 'Vuelve a dibujar sin créditos hasta $count vez al día',
    );
    return '$_temp0';
  }

  @override
  String get planBenefitMoreWeeklyCredits => 'Recibe más créditos cada semana';

  @override
  String get planBenefitMoreMonthlyCredits => 'Recibe más créditos cada mes';

  @override
  String get planBenefitCardExportWithoutWatermark =>
      'Impresiones limpias sin franja abajo';

  @override
  String get planBenefitCardExportAllThemes =>
      'Elige entre todos los diseños de impresión';

  @override
  String get planBenefitCardExportAllLayouts =>
      'Imprime una rutina en una página o tarjetas para recortar';

  @override
  String get planKeepContentNotice =>
      'Las rutinas y las imágenes que hiciste se quedan aunque termine Pro';

  @override
  String get planPeriodMonthly => '1 mes';

  @override
  String get planPeriodYearly => '1 año';

  @override
  String get planSubscribe => 'Empezar la suscripción';

  @override
  String get planPriceLoading => 'Cargando precios';

  @override
  String get planPriceFailed => 'No se pudieron cargar los precios';

  @override
  String get planRestore => 'Restaurar compras';

  @override
  String get planTermsOfUse => 'Términos de uso';

  @override
  String get planPrivacyPolicy => 'Política de privacidad';

  @override
  String get planManageSubscription => 'Gestionar suscripción';

  @override
  String get planLegalBillingAppStore =>
      'El pago se carga a tu cuenta de Apple ID al confirmar la compra. La suscripción se renueva automáticamente con la misma duración y precio, salvo que la canceles al menos 24 horas antes de que termine el periodo. El siguiente periodo se carga a tu cuenta dentro de las 24 horas previas a su fin.';

  @override
  String get planLegalCancelAppStore =>
      'Puedes gestionar y cancelar tu suscripción en Ajustes > Apple ID > Suscripciones de tu dispositivo. Después de cancelar, puedes usar Pro hasta el final del periodo pagado.';

  @override
  String get planLegalBillingPlayStore =>
      'El pago se carga a tu cuenta de Google Play al confirmar la compra. La suscripción se renueva automáticamente con la misma duración y precio hasta que la canceles.';

  @override
  String get planLegalCancelPlayStore =>
      'Puedes gestionar y cancelar tu suscripción en Google Play Store, en Pagos y suscripciones > Suscripciones. Después de cancelar, puedes usar Pro hasta el final del periodo pagado.';

  @override
  String planTrialDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String planTrialMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '$count mes',
    );
    return '$_temp0';
  }

  @override
  String planTrialYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años',
      one: '$count año',
    );
    return '$_temp0';
  }

  @override
  String planStartFreeTrial(String trial) {
    return 'Empezar $trial gratis';
  }

  @override
  String get planLegalTrialAppStore =>
      'Si cancelas al menos 24 horas antes de que termine la prueba gratuita, no se te cobrará.';

  @override
  String get planLegalTrialPlayStore =>
      'Si cancelas durante la prueba gratuita, no se te cobrará.';

  @override
  String get planVerifying => 'Confirmando tu pago';

  @override
  String get planStorePendingTitle => 'Se pidió la aprobación del pago';

  @override
  String get planStorePendingBody =>
      'Pro se activa cuando se apruebe. Puedes cerrar esta pantalla.';

  @override
  String get planVerificationPendingTitle => 'Confirmando tu pago';

  @override
  String get planVerificationPendingBody =>
      'No tienes que pagar de nuevo. Lo comprobaremos otra vez cuando vuelvas a abrir la app';

  @override
  String get planVerificationRetry => 'Comprobar de nuevo';

  @override
  String get planActivatedStart => 'Empezar';

  @override
  String get planActivatedTitle => 'Pro ya empezó';

  @override
  String get planNotActivatedTitle => 'Pro aún no está activo';

  @override
  String get planNotActivatedBodyApple =>
      'Revisa tu suscripción de elum en la app App Store → tu foto arriba a la derecha → Suscripciones';

  @override
  String get planNotActivatedBodyGoogle =>
      'Revisa tu suscripción de elum en la app Play Store → perfil arriba a la derecha → Pagos y suscripciones → Suscripciones';

  @override
  String get planOpenAppStore => 'Revisar en App Store';

  @override
  String get planOpenPlayStore => 'Revisar en Play Store';

  @override
  String get planAlreadyProTitle => 'Ya usas Pro';

  @override
  String get planPurchaseFailedTitle => 'No se pudo completar el pago';

  @override
  String get planVerifyFailedTitle =>
      'No se pudo vincular el pago a esta cuenta';

  @override
  String get planAccountFailedTitle => 'No se pudo comprobar tu cuenta';

  @override
  String get planFailedFallback => 'Inténtalo de nuevo en un momento';

  @override
  String get planRestoreDone => 'Pro ha vuelto';

  @override
  String get planRestoreNothing => 'No hay ninguna suscripción para restaurar';

  @override
  String get planRestoreNothingHintApple =>
      'Comprueba que este dispositivo tenga iniciada la sesión con el Apple ID con el que te suscribiste. También debes iniciar sesión en elum de la misma forma que al suscribirte';

  @override
  String get planRestoreNothingHintGoogle =>
      'Comprueba que Play Store tenga iniciada la sesión con la cuenta de Google con la que te suscribiste. También debes iniciar sesión en elum de la misma forma que al suscribirte';

  @override
  String get planRestoreFailedTitle => 'No se pudo restaurar tu compra';

  @override
  String get planRestoring => 'Revisando tus compras';

  @override
  String get planManageFailed =>
      'No se pudo abrir la gestión de la suscripción';

  @override
  String get planLinkFailed => 'No se pudo abrir el enlace';

  @override
  String get planSettingsLabel => 'Mi plan';

  @override
  String get planStatusFree => 'Gratis';

  @override
  String get planStatusPro => 'Pro';

  @override
  String planStatusRenewing(String date) {
    return 'Pro, se renueva el $date';
  }

  @override
  String planStatusUntil(String date) {
    return 'Pro, hasta el $date';
  }

  @override
  String planStatusCancelScheduled(String date) {
    return 'Pro, termina el $date';
  }

  @override
  String get planStatusGracePeriod => 'Pro, revisa el pago';

  @override
  String planStatusTrial(int days) {
    return 'Prueba de Pro, quedan $days días';
  }

  @override
  String get planStatusTrialLastDay => 'Prueba de Pro, termina hoy';

  @override
  String get planStatusGift => 'Pro de regalo';

  @override
  String planStatusGiftUntil(String date) {
    return 'Pro de regalo, hasta el $date';
  }

  @override
  String planStatusRenewingFooter(String date) {
    return 'Se renueva el $date';
  }

  @override
  String planStatusUntilFooter(String date) {
    return 'Puedes usarlo hasta el $date';
  }

  @override
  String planStatusCancelScheduledFooter(String date) {
    return 'Termina el $date';
  }

  @override
  String get planStatusGracePeriodFooter => 'Revisa tu método de pago';

  @override
  String get planSheetNextPaymentLabel => 'Próximo pago';

  @override
  String get planSheetEndDateLabel => 'Termina el';

  @override
  String get planSheetStoreLabel => 'Pagado con';

  @override
  String get planSheetStoreAppStore => 'App Store';

  @override
  String get planSheetStoreGooglePlay => 'Google Play';

  @override
  String planSheetRenewingNote(String date) {
    return 'Si no cancelas, se te cobrará automáticamente el $date. Puedes cancelar en Gestionar suscripción';
  }

  @override
  String get planSheetEndsToFreeNote =>
      'Cuando termine, pasarás a Gratis. No se te cobrará automáticamente';

  @override
  String get planSheetUnlimitedNote => 'Puedes usar Pro sin fecha de fin';

  @override
  String get planLearnPro => 'Conoce Pro';

  @override
  String get weeklyReportTitle => 'Informe semanal';

  @override
  String weeklyReportWeekRange(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startDay/$startMonth - $endDay/$endMonth';
  }

  @override
  String weeklyReportThisWeekRange(String range) {
    return 'Esta semana · $range';
  }

  @override
  String get weeklyReportPreviousWeek => 'Ver la semana pasada';

  @override
  String get weeklyReportNextWeek => 'Ver la semana siguiente';

  @override
  String get weeklyReportCompletionLabel => 'Rutinas terminadas';

  @override
  String weeklyReportPercent(int percent) {
    return '$percent %';
  }

  @override
  String weeklyReportCompletionSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: 'Terminó $completed de $sent rutinas enviadas',
      one: 'Terminó $completed de $sent rutina enviada',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportDayNone => '-';

  @override
  String weeklyReportDayCount(int completed, int sent) {
    return '$completed/$sent';
  }

  @override
  String get weeklyReportStars => 'Estrellas ganadas';

  @override
  String get weeklyReportRewards => 'Rutinas con recompensa';

  @override
  String get weeklyReportStreak => 'Días seguidos terminados';

  @override
  String weeklyReportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '$count',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRoutinesSection => 'Por rutina';

  @override
  String weeklyReportRoutineValue(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: 'Terminó $completed de $sent veces',
      one: 'Terminó $completed de $sent vez',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRemainingSection =>
      'Tarjetas que a menudo quedan sin hacer';

  @override
  String weeklyReportRemainingLabel(String routine, String step) {
    return '$routine · $step';
  }

  @override
  String weeklyReportTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veces',
      one: '$count vez',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportEmptyTitle => 'Esta semana no se enviaron rutinas';

  @override
  String get weeklyReportEmptyBody =>
      'Cuando envíes rutinas, aquí se reunirán los registros de lo que Elumi termina';

  @override
  String get weeklyReportNoCompletionThisWeekTitle =>
      'Aún no hay registros esta semana';

  @override
  String get weeklyReportNoCompletionPastWeekTitle =>
      'Esta semana no se terminó ninguna rutina';

  @override
  String get weeklyReportNoCompletionBody => '¿Envías una rutina para hoy?';

  @override
  String get weeklyReportGoToManage => 'Ir a Rutinas';

  @override
  String get weeklyReportLoadFailed => 'No se pudo cargar el informe semanal';

  @override
  String get weeklyReportNotIncluded =>
      'El informe semanal está disponible con Pro';

  @override
  String get weeklyReportShareImage => 'Imagen';

  @override
  String get weeklyReportSharePdf => 'PDF';

  @override
  String get weeklyReportShareFailed =>
      'No se pudo crear la página para enviar';

  @override
  String weeklyReportShareTitle(String name, String batchim) {
    return 'La semana de $name';
  }

  @override
  String get weeklyReportShareNote =>
      'Calculado a partir de los registros de la app de Elumi';

  @override
  String get weeklyReportRecordSection => 'Registro de esta semana';

  @override
  String get weeklyReportDonutLabel => 'Tasa de finalización';

  @override
  String weeklyReportDonutSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$completed de $sent rutinas completadas',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDonutSemantics(int percent, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other:
          'Tasa de finalización $percent por ciento, $completed de $sent rutinas completadas',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportDaysSection => 'Registro por día';

  @override
  String weeklyReportDayBarSemantics(String weekday, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$weekday: $completed de $sent rutinas completadas',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDayBarEmptySemantics(String weekday) {
    return '$weekday: sin rutinas enviadas';
  }

  @override
  String get weeklyReportTrendSection => 'Comparación con semanas anteriores';

  @override
  String weeklyReportTrendWeekLabel(int month, int day) {
    return '$day/$month';
  }

  @override
  String weeklyReportTrendPointSemantics(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Semana del $day/$month: $count rutinas completadas',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportInsightHighlightTitle => 'Lo que salió bien';

  @override
  String weeklyReportInsightHighlightFirst(String routine, String batchim) {
    return 'Terminó $routine hasta el final por primera vez esta semana';
  }

  @override
  String weeklyReportInsightHighlightEvery(
    String routine,
    String batchim,
    int count,
  ) {
    return 'Terminó $routine hasta el final las $count veces';
  }

  @override
  String weeklyReportInsightHighlightStreak(int days) {
    return 'Terminó rutinas $days días seguidos';
  }

  @override
  String weeklyReportInsightHighlightHint(String name) {
    return 'Cuéntaselo hoy a $name';
  }

  @override
  String get weeklyReportInsightStuckTitle => 'Dónde se detiene a menudo';

  @override
  String weeklyReportInsightStuckLine(
    String routine,
    String step,
    int sent,
    int remained,
  ) {
    return 'Se detuvo en $step de $routine $remained de $sent veces';
  }

  @override
  String get weeklyReportInsightStuckShorten =>
      'Puedes acortar el texto de la tarjeta o dividirla en dos';

  @override
  String get weeklyReportInsightStuckAddMedia =>
      'Puedes añadir una voz o una foto';

  @override
  String weeklyReportInsightStuckFix(String step) {
    return 'Editar la tarjeta $step';
  }

  @override
  String get weeklyReportInsightStuckFixFailed =>
      'No se pudo abrir la rutina para editarla';

  @override
  String get weeklyReportInsightTrendTitle => 'Cambios desde la semana pasada';

  @override
  String weeklyReportInsightTrendUp(int before, int after) {
    return 'Las rutinas terminadas subieron de $before a $after';
  }

  @override
  String weeklyReportInsightTrendDown(int before, int after) {
    return 'Las rutinas terminadas pasaron de $before a $after';
  }

  @override
  String weeklyReportInsightTrendSame(int after) {
    return 'Terminó $after otra vez, igual que la semana pasada';
  }

  @override
  String weeklyReportInsightTrendBarPrevious(int count) {
    return 'Semana pasada $count';
  }

  @override
  String weeklyReportInsightTrendBarCurrent(int count) {
    return 'Esta semana $count';
  }

  @override
  String get weeklyReportInsightDurationTitle => 'Tiempo que tardó';

  @override
  String weeklyReportInsightDurationLine(
    String routine,
    int before,
    int after,
  ) {
    return 'El tiempo de $routine pasó de $before min a $after min';
  }

  @override
  String get weeklyReportInsightSlowestTitle =>
      'La tarjeta en la que más tiempo estuvo';

  @override
  String weeklyReportInsightSlowestLine(
    String routine,
    String step,
    int minutes,
  ) {
    return 'Estuvo $minutes min de media en $step de $routine';
  }

  @override
  String get weeklyReportStatCompleted => 'Rutinas terminadas';

  @override
  String get weeklyReportStatRemaining => 'Tarjetas sin hacer';

  @override
  String weeklyReportRoutineRatio(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$completed de $sent veces',
      one: '$completed de $sent vez',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportSave => 'Guardar informe';

  @override
  String get weeklyReportSaveSheetTitle => '¿Cómo quieres guardar el informe?';

  @override
  String get weeklyReportPastReports => 'Ver informes anteriores';

  @override
  String get weeklyReportPastSheetTitle => 'Informes anteriores';

  @override
  String weeklyReportPastWeekValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Terminó $count rutinas',
      one: 'Terminó $count rutina',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportPastEmpty => 'Aún no hay informes anteriores';

  @override
  String get weeklyReportPastLoadFailed =>
      'No se pudieron cargar los informes anteriores';

  @override
  String get weeklyReportFreePreviewNote =>
      'Puedes ver tu primer informe sin Pro';

  @override
  String get weeklyReportNextWeekUpsell =>
      'Recibe también el informe de la próxima semana';

  @override
  String get routineScheduleRowOff => 'Elegir días y hora';

  @override
  String get routineScheduleRowLabel => 'Días y hora para repetir';

  @override
  String routineScheduleSummary(String days, String time) {
    return '$days $time';
  }

  @override
  String get routineScheduleEveryDay => 'Todos los días';

  @override
  String get routineScheduleWeekdaysOnly => 'Entre semana';

  @override
  String get routineScheduleWeekendOnly => 'Fines de semana';

  @override
  String get routineScheduleDaySeparator => '·';

  @override
  String get routineSchedulePaused => 'En pausa porque terminó Pro';

  @override
  String get routineSchedulePausedNote =>
      'La repetición está en pausa porque terminó Pro. Tus días y hora siguen guardados';

  @override
  String get routineScheduleSheetTitle => '¿Cuándo debe ser?';

  @override
  String get routineScheduleSheetBody =>
      'Cada día que elijas, esta rutina pasa a las rutinas de hoy';

  @override
  String get routineScheduleDaysLabel => 'Días';

  @override
  String get routineScheduleTimeLabel => 'Hora';

  @override
  String get routineScheduleNotifyElumi =>
      'Avisar al dispositivo de Elumi a esa hora';

  @override
  String get routineScheduleElumiNotificationOff =>
      'Las notificaciones están desactivadas en el dispositivo de Elumi';

  @override
  String get routineScheduleElumiNotificationOffHint =>
      'Activa las notificaciones de Elumi en los ajustes del dispositivo de Elumi';

  @override
  String get routineScheduleElumiNoDevice =>
      'Cuando conectes el dispositivo de Elumi, recibirá un aviso a esa hora';

  @override
  String get routineScheduleSave => 'Guardar';

  @override
  String get routineScheduleTurnOff => 'Desactivar la repetición';

  @override
  String get routineScheduleSavedToast => 'Guardaste los días y la hora';

  @override
  String get routineScheduleTurnedOffToast => 'Desactivaste la repetición';

  @override
  String get routineScheduleSaveFailedTitle => 'No se pudo guardar';

  @override
  String get routineScheduleSaveFailedFallback =>
      'Inténtalo de nuevo en un momento';

  @override
  String get routineSchedulePickDayHint => 'Elige al menos un día';

  @override
  String get routineScheduleProNote =>
      'Puedes guardar rutinas que se repiten con Pro';

  @override
  String get weeklyPlanEntry => 'Plan semanal';

  @override
  String get weeklyPlanTitle => 'Plan semanal';

  @override
  String weeklyPlanDayTitle(String weekday) {
    return '$weekday';
  }

  @override
  String get weeklyPlanToday => 'Hoy';

  @override
  String get weeklyPlanEmptyDay => 'No hay rutinas planeadas';

  @override
  String get weeklyPlanEmptyTitle => 'Aún ninguna rutina tiene días elegidos';

  @override
  String get weeklyPlanEmptyBody =>
      'En Rutinas, toca una rutina y elige sus días y hora';

  @override
  String get weeklyPlanLoadFailed => 'No se pudo cargar el plan semanal';

  @override
  String get weeklyPlanNotifyOff => 'Sin aviso';

  @override
  String get weeklyPlanMetaSeparator => ' · ';

  @override
  String get guardianVoiceRecordAction => 'Grabar con mi voz';

  @override
  String get guardianVoiceRecordHint => 'Al tocar una tarjeta, suena esta voz';

  @override
  String guardianVoiceRecording(int seconds) {
    return 'Grabando $seconds s';
  }

  @override
  String guardianVoiceRecordingLimit(int seconds) {
    return 'Graba hasta $seconds s';
  }

  @override
  String get guardianVoiceStop => 'Detener';

  @override
  String get guardianVoiceSaving => 'Guardando tu grabación';

  @override
  String get guardianVoiceSaved => 'Grabado';

  @override
  String get guardianVoicePlay => 'Escuchar';

  @override
  String get guardianVoiceRerecord => 'Grabar de nuevo';

  @override
  String get guardianVoiceDelete => 'Eliminar';

  @override
  String get guardianVoiceDeleteConfirmTitle => '¿Eliminar la grabación?';

  @override
  String get guardianVoiceDeleteConfirmMessage =>
      'Si la eliminas, la voz básica leerá la tarjeta';

  @override
  String get guardianVoicePlanEnded => 'Se lee con la voz básica';

  @override
  String get guardianVoiceMicDeniedTitle => 'El micrófono está desactivado';

  @override
  String get guardianVoiceMicDeniedBody =>
      'Hasta que lo actives, la voz básica leerá la tarjeta';

  @override
  String get guardianVoiceOpenSettings => 'Abrir ajustes';

  @override
  String get guardianVoiceFailedTitle => 'No se pudo guardar la grabación';

  @override
  String get guardianVoiceRetry => 'Reintentar';

  @override
  String get guardianVoiceTooShort =>
      'Es muy corta. Habla y luego toca Detener';

  @override
  String get guardianVoiceRecordFailed =>
      'No se pudo grabar. Inténtalo de nuevo';

  @override
  String get guardianVoiceTooLarge =>
      'La grabación es muy grande. Graba una más corta';

  @override
  String get guardianVoicePlayFailed => 'No se pudo reproducir la grabación';

  @override
  String get guardianVoiceDeleteFailed => 'No se pudo eliminar la grabación';

  @override
  String get guardianVoiceRecordChip => 'Grabar';

  @override
  String get guardianVoicePlanEndedHint =>
      'Tu grabación se guarda aunque termine Pro';

  @override
  String get guardianSettingsRoutineMemory => 'Memoria de IA';

  @override
  String memoryHeroTitle(String name) {
    return 'Memoria de IA de $name';
  }

  @override
  String get memoryHeroBody =>
      'Recuerda cómo editas y hace así tus próximas rutinas. Solo tú lo ves';

  @override
  String get memoryStatApplied => 'En uso';

  @override
  String get memoryStatWatching => 'Observando';

  @override
  String get memoryStatEdits => 'Ediciones';

  @override
  String get memoryListAppliedHeader => 'Reglas en uso';

  @override
  String get memoryListAppliedHint => 'Se usan en las rutinas nuevas';

  @override
  String get memoryListWatchingHeader => 'Reglas en observación';

  @override
  String get memoryListWatchingHint => 'Se aplican cuando se llenan los puntos';

  @override
  String get memoryListEditsHeader => 'Editado y enviado';

  @override
  String memoryRuleByAi(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rutinas',
      one: '$count rutina',
    );
    return 'Encontrada por la IA, $_temp0';
  }

  @override
  String get memoryRuleByMe => 'Escrita por mí';

  @override
  String memoryEditCards(int before, int after) {
    return '$before → $after tarjetas';
  }

  @override
  String memoryEditTexts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count textos',
      one: '$count texto',
    );
    return '$_temp0';
  }

  @override
  String get memoryAddRule => '+ Escribir una regla';

  @override
  String get memoryAutoFind => 'Buscar en mis ediciones automáticamente';

  @override
  String memoryAutoFindNote(int count) {
    return 'Se aplica cuando la misma edición se repite en $count rutinas';
  }

  @override
  String get memoryEmptyTitle =>
      'Cuando edites y envíes rutinas, se guardarán aquí';

  @override
  String get memoryEmptyEdits => 'Aún no has enviado rutinas editadas';

  @override
  String get memoryTypeWord => 'Cambiar una palabra';

  @override
  String get memoryTypeSplit => 'Dividir una tarjeta';

  @override
  String get memoryTypeMerge => 'Unir tarjetas';

  @override
  String get memoryTypeAdd => 'Añadir una tarjeta';

  @override
  String get memoryTypeRemove => 'Quitar una tarjeta';

  @override
  String get memoryTypeManual => 'Regla escrita por mí';

  @override
  String get memoryApplyNow => 'Aplicar ahora';

  @override
  String get memoryRuleDelete => 'Eliminar';

  @override
  String get memoryRuleEdit => 'Editar';

  @override
  String memoryEvidenceLine(String routine, int month, int day) {
    return '$routine, $day/$month';
  }

  @override
  String get memoryMenuLabel => 'Menú';

  @override
  String get memoryMenuExport => 'Exportar como archivo';

  @override
  String get memoryMenuClear => 'Borrar toda la memoria';

  @override
  String get memoryExportFailed => 'No se pudo exportar tu memoria';

  @override
  String get memoryObsTitle => 'Memoria de IA';

  @override
  String get memoryObsWord => 'Cambiaste una palabra así';

  @override
  String get memoryObsSplit => 'Dividiste una tarjeta';

  @override
  String get memoryObsMerge => 'Uniste tarjetas';

  @override
  String get memoryObsAdd => 'Añadiste una tarjeta';

  @override
  String get memoryObsRemove => 'Quitaste una tarjeta';

  @override
  String get memoryObsManual => 'Lo editaste así';

  @override
  String memoryObsAsk(String phrase) {
    return '$phrase. ¿Lo hacemos así también en la próxima rutina?';
  }

  @override
  String get memoryObsAlways => 'Siempre así';

  @override
  String get memoryObsOnce => 'Solo esta vez';

  @override
  String get memoryObsDone => 'Desde la próxima rutina lo haremos así';

  @override
  String memoryObsMore(int count) {
    return 'Ver $count más en la memoria de IA';
  }

  @override
  String memoryAppliedPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas de memoria de IA aplicadas',
      one: '$count regla de memoria de IA aplicada',
    );
    return '$_temp0';
  }

  @override
  String get routineMemoryAddSheetTitle => 'Añadir una nota';

  @override
  String get routineMemoryEditSheetTitle => 'Editar la nota';

  @override
  String get routineMemoryLineHint =>
      'Ej.: escribe \'limpiarse las manos\' en vez de \'lavarse\'';

  @override
  String get routineMemorySave => 'Guardar';

  @override
  String get routineMemoryDeleteLine => 'Borrar esta línea';

  @override
  String get routineMemoryClearConfirmTitle => '¿Borrar todas las notas?';

  @override
  String get routineMemoryClearConfirmMessage =>
      'Las notas borradas no se pueden recuperar.';

  @override
  String get routineMemoryClearConfirmAction => 'Borrar todo';

  @override
  String get routineMemoryLoadFailed => 'No se pudieron cargar las notas';

  @override
  String get routineMemorySaveFailedTitle => 'No se pudo guardar la nota';

  @override
  String get routineMemorySaveFailedFallback =>
      'Inténtalo de nuevo en un momento.';

  @override
  String get proTeaserSampleLabel => 'Pantalla de ejemplo';

  @override
  String get proOnlyNoticeTitle => 'Esta función está disponible con Pro';

  @override
  String get proOnlyFreeAlternative =>
      'Todo lo que usas ahora sigue funcionando';

  @override
  String get proOnlyFreeAlternativeAiImage =>
      'Por ahora puedes crear tarjetas con imágenes básicas o fotos';

  @override
  String get proOnlyFreeAlternativeSchedule =>
      'Por ahora puedes enviar las rutinas tú mismo';

  @override
  String get proOnlyFreeAlternativeVoice =>
      'Por ahora las tarjetas se leen con la voz básica';

  @override
  String get proOnlyFreeAlternativeCardSplit =>
      'Por ahora puedes dividirla añadiendo tarjetas tú mismo';

  @override
  String get proOnlyFreeAlternativeCardExport =>
      'Por ahora puedes imprimir con el diseño básico';

  @override
  String get proTeaserWeeklyReportBenefit =>
      'Envía un resumen de una página con las rutinas hechas en la semana';

  @override
  String get proTeaserRoutineMemoryBenefit =>
      'Recuerda cómo editas para que las próximas rutinas encajen mejor';

  @override
  String get proTeaserCardThemeBenefit =>
      'Recibe tarjetas para imprimir con varios diseños';

  @override
  String get proTeaserWeeklyPlanBenefit =>
      'No tienes que enviar la rutina cada mañana';

  @override
  String get proTeaserSampleRoutineMorning => 'Prepararse por la mañana';

  @override
  String get proTeaserSampleRoutineBrush => 'Lavarse los dientes';

  @override
  String get proTeaserSampleRoutineBag => 'Preparar la mochila';

  @override
  String get proTeaserSampleStepSocks => 'Ponerse los calcetines';

  @override
  String get proTeaserSampleMemoryShort =>
      'Escribe el texto de la tarjeta corto, en una línea';

  @override
  String get proTeaserSampleMemoryOrder =>
      'Empieza a vestirte por los calcetines';

  @override
  String get proTeaserSampleMemoryReward => 'Elige pegatinas como recompensa';

  @override
  String get cardRegenerateChip => 'Volver a dibujar';

  @override
  String get cardRegenerateSheetTitle => '¿Volver a dibujar la imagen?';

  @override
  String cardRegenerateCostProFree(int count) {
    return 'Sin créditos, te quedan $count hoy';
  }

  @override
  String get cardRegenerateCostFree => 'No usa créditos';

  @override
  String cardRegenerateCostCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count créditos',
      one: '$count crédito',
    );
    return '$_temp0';
  }

  @override
  String cardRegenerateCostProUsedUp(int credits, int freeCount) {
    String _temp0 = intl.Intl.pluralLogic(
      credits,
      locale: localeName,
      other:
          'Ya usaste los $freeCount dibujos gratis de hoy, usa $credits créditos',
      one:
          'Ya usaste los $freeCount dibujos gratis de hoy, usa $credits crédito',
    );
    return '$_temp0';
  }

  @override
  String cardRegenerateProFact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Con Pro vuelves a dibujar gratis $count veces al día',
      one: 'Con Pro vuelves a dibujar gratis $count vez al día',
    );
    return '$_temp0';
  }

  @override
  String cardAddImageCost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dibujar una imagen con IA usa $count créditos',
      one: 'Dibujar una imagen con IA usa $count crédito',
    );
    return '$_temp0';
  }

  @override
  String questionCreditCostLine(String costs, int available) {
    String _temp0 = intl.Intl.pluralLogic(
      available,
      locale: localeName,
      other: '$costs, tienes $available',
      one: '$costs, tienes $available',
    );
    return '$_temp0';
  }

  @override
  String creditCostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '$count',
    );
    return '$_temp0';
  }

  @override
  String get cardRegenerateCostUnknown => 'Usa créditos';

  @override
  String get cardRegenerateConfirm => 'Volver a dibujar';

  @override
  String get cardRegenerateInProgress => 'Volviendo a dibujar la imagen';

  @override
  String get cardRegenerateFailedTitle =>
      'No se pudo volver a dibujar la imagen';

  @override
  String get cardFirstDrawChip => 'Dibujar con IA';

  @override
  String get cardRedrawProChip => 'Volver a dibujar con Pro';

  @override
  String get cardFirstDrawProChip => 'Dibujar con IA con Pro';

  @override
  String get cardFirstDrawSheetTitle => '¿Dibujar una imagen con IA?';

  @override
  String get cardRedrawSheetBody =>
      'Escribe o elige lo que quieres cambiar. Si lo dejas vacío, se dibuja igual otra vez';

  @override
  String get cardFirstDrawSheetBody =>
      'Escribe o elige lo que quieres. Podrás elegir después de ver la nueva imagen';

  @override
  String get cardRedrawRequestLabel => 'Qué cambiar';

  @override
  String get cardRedrawRequestHint => 'Ej.: el paraguas en azul';

  @override
  String get cardRedrawHintSimpler => 'Más sencillo';

  @override
  String get cardRedrawHintNoBackground => 'Sin fondo';

  @override
  String get cardRedrawHintNoPeople => 'Sin personas';

  @override
  String get cardRedrawHintBrighter => 'Más claro';

  @override
  String get cardFirstDrawConfirm => 'Dibujar';

  @override
  String get cardFirstDrawInProgress => 'Dibujando la imagen';

  @override
  String get cardFirstDrawFailedTitle => 'No se pudo dibujar la imagen con IA';

  @override
  String get cardRedrawFailedFallback =>
      '¿Lo intentamos otra vez? No se usaron créditos';

  @override
  String get cardCandidateFailedFallback =>
      'La nueva imagen ya se dibujó, así que los créditos usados no se devuelven. Inténtalo de nuevo en un momento';

  @override
  String get cardCandidateSheetTitle => '¿Qué imagen prefieres?';

  @override
  String get cardCandidateSheetBody =>
      'Elumi solo verá la imagen que elijas\nElijas la que elijas, los créditos usados no se devuelven';

  @override
  String get cardCandidateCurrentLabel => 'Actual';

  @override
  String get cardCandidateNewLabel => 'Nueva';

  @override
  String get cardCandidateSelectButton => 'Usar esta imagen';

  @override
  String get cardCandidateAppliedToast => 'Cambiaste a la nueva imagen';

  @override
  String get cardCandidateLoadFailedTitle =>
      'No se pudo cargar la nueva imagen';

  @override
  String get cardCandidateApplyFailedTitle =>
      'No se pudo cambiar a la nueva imagen';

  @override
  String get planHeroHeadline => 'Tarjetas hechas solo para Elumi';

  @override
  String get planHeroSubline => 'La misma rutina hecha con Pro se ve así';

  @override
  String get planHeroFreeTag => 'Free: emoji';

  @override
  String get planHeroProTag => 'Pro: dibujo animado';

  @override
  String get planHeroCompareSemantics =>
      'Free da tarjetas con emoji, Pro da tarjetas con dibujos animados';

  @override
  String planBenefitGroupCards(String elumiName) {
    return 'Imágenes de tarjetas solo para $elumiName';
  }

  @override
  String get planBenefitGroupRoutines => 'Las rutinas se envían solas';

  @override
  String get planBenefitGroupWeek => 'Te resumimos la semana';

  @override
  String get planBenefitGroupExtra => 'Un poco más de margen';

  @override
  String planYearlySaving(int percent) {
    return 'Ahorra un $percent%';
  }

  @override
  String get planRenewsYearly => 'Se renueva cada año';

  @override
  String get planRenewsMonthly => 'Se renueva cada mes';

  @override
  String planMonthlyEquivalentRenewsYearly(String price) {
    return 'Unos $price al mes · Se renueva cada año';
  }

  @override
  String planPriceUnit(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'yearly': '/año',
      'other': '/mes',
    });
    return '$_temp0';
  }

  @override
  String planCtaTrialNoticeAppStore(String trial, String price, String unit) {
    return 'Después de $trial, se cobra $price$unit automáticamente. Cancela al menos 24 horas antes de que termine para que no se te cobre';
  }

  @override
  String planCtaTrialNoticePlayStore(String trial, String price, String unit) {
    return 'Después de $trial, se cobra $price$unit automáticamente. Cancela durante la prueba para que no se te cobre';
  }

  @override
  String planCtaRenewNotice(String price, String unit) {
    return 'Se renueva automáticamente por $price$unit. Cancela cuando quieras';
  }

  @override
  String planTryFreeTrial(String trial) {
    return 'Prueba gratis $trial';
  }

  @override
  String get planSeeAllBenefits => 'Ver todas las ventajas de Pro';

  @override
  String get planTierGift => 'Regalo';

  @override
  String get myPlanProTitle => 'Usas Pro';

  @override
  String get myPlanGiftTitle => 'Recibiste Pro de regalo';

  @override
  String get myPlanFreeTitle => 'Usas Free';

  @override
  String get myPlanFreeBodyWeek =>
      'Crea rutinas con los créditos que recibes cada semana';

  @override
  String get myPlanFreeBodyMonth =>
      'Crea rutinas con los créditos que recibes cada mes';

  @override
  String get proTeaserWeeklyPlanTitle =>
      'Elige los días y la hora, y la rutina de ese día estará lista';

  @override
  String get proTeaserWeeklyReportTitle =>
      'Recibe toda la semana en una página';

  @override
  String get proTeaserRoutineMemoryTitle =>
      'Recuerda lo que le funciona a Elumi';

  @override
  String get proTeaserCardThemeTitle =>
      'Recibe tarjetas para imprimir más bonitas';

  @override
  String get proTeaserCardLayoutTitle =>
      'Recibe tarjetas para imprimir a tu manera';

  @override
  String get proTeaserCardLayoutBenefit =>
      'Elige varias tarjetas por hoja, papel horizontal o la rutina en una hoja';

  @override
  String get homeSuggestionDismissLabel => 'No, gracias';

  @override
  String get homeSuggestionAutoSendTitle =>
      '¿Enviarla automáticamente cada día?';

  @override
  String homeSuggestionAutoSendBody(String routine, String batchim, int days) {
    return 'Has enviado $routine $days días seguidos';
  }

  @override
  String get homeSuggestionAutoSendAction => 'Configurar';

  @override
  String get homeSuggestionTalkShareTitle => '¿La compartimos en Historias?';

  @override
  String homeSuggestionTalkShareBody(String routine, String batchim) {
    return 'Otros tutores también pueden usar $routine';
  }

  @override
  String get homeSuggestionTalkShareAction => 'Compartir';

  @override
  String get homeSuggestionCreateMoreTitle => '¿Creamos otra rutina?';

  @override
  String get homeSuggestionCreateMoreBody =>
      '¿Qué tal una para la tarde o antes de dormir?';

  @override
  String get homeSuggestionCreateMoreAction => 'Crear';

  @override
  String get cardSplitChip => 'Hacer esta tarjeta más fácil';

  @override
  String get cardSplitLoading => 'Dividiéndola en pasos más fáciles';

  @override
  String get cardSplitSheetTitle => '¿La dividimos así?';

  @override
  String cardSplitSheetDescription(String title, int count) {
    return 'Dividimos “$title” en $count pasos más pequeños';
  }

  @override
  String get cardSplitAlreadyShortDescription =>
      'Ya es una sola acción, así que la dejamos igual';

  @override
  String get cardSplitDefaultPictureNote =>
      'Llevarán la imagen básica. Puedes cambiarla después';

  @override
  String get cardSplitKeepButton => 'Dejarla así';

  @override
  String get cardSplitApplyButton => 'Dividir así';

  @override
  String get cardSplitAlreadyShort => 'Ya es suficientemente corta';

  @override
  String get cardSplitFailedFallback =>
      'No se pudo dividir la tarjeta. Inténtalo de nuevo en un momento';

  @override
  String get cardSplitRetry => 'Reintentar';

  @override
  String cardSplitDoneToast(int count) {
    return 'Dividimos la tarjeta en $count';
  }

  @override
  String get planBenefitCardSplit => 'Divide una tarjeta en otras más pequeñas';

  @override
  String get creditTopUpTitleExhausted =>
      '🎟️ Ya usaste los créditos de esta semana';

  @override
  String get creditTopUpTitleExhaustedMonth =>
      '🎟️ Ya usaste los créditos de este mes';

  @override
  String get creditTopUpTitleShort => '🎟️ Te faltan algunos créditos';

  @override
  String creditTopUpRefillAt(String reset) {
    return 'Se recargan el $reset';
  }

  @override
  String get creditTopUpAdTitleNoCount => 'Mira un anuncio y recibe créditos';

  @override
  String get creditTopUpAdWatch => 'Ver anuncio';

  @override
  String get creditTopUpAdOff =>
      'Ahora no puedes recibir créditos con anuncios';

  @override
  String get creditTopUpAdDailyLimit =>
      'Ya recibiste todos los de hoy. Vuelve mañana';

  @override
  String creditTopUpAdDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'De 15 a 30 segundos, mira hasta el final y recibe $count créditos',
      one: 'De 15 a 30 segundos, mira hasta el final y recibe $count crédito',
    );
    return '$_temp0';
  }

  @override
  String creditTopUpAdRemaining(int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'Puedes recibir $remaining veces más hoy',
      one: 'Puedes recibir $remaining vez más hoy',
    );
    return '$_temp0';
  }

  @override
  String get creditTopUpAdNoFill => 'Ahora no hay anuncios disponibles';

  @override
  String get proFeatureMarkLabel => 'Ver más';

  @override
  String get proExplainAiImageStylesReason =>
      'Dibujos que encajan con cada tarjeta, más fáciles de reconocer para Elumi';

  @override
  String get proExplainCardSplitReason =>
      'Las tareas difíciles se dividen en pasos pequeños que Elumi sigue uno a uno';

  @override
  String get proExplainFreeImageRegenerateReason =>
      'Corrige el dibujo hasta que te guste sin preocuparte por los créditos';

  @override
  String get creditTopUpAdCheckFailed =>
      'No se pudo cargar la información del anuncio. Ábrelo de nuevo en un momento';

  @override
  String get creditTopUpPackLink => 'Ver paquetes de créditos';

  @override
  String get creditTopUpRoutineContinue => 'Seguir creando';

  @override
  String get creditTopUpRedrawContinue => 'Seguir dibujando';

  @override
  String creditRewardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🎟️ Recibiste $count créditos',
      one: '🎟️ Recibiste $count crédito',
    );
    return '$_temp0';
  }

  @override
  String get creditRewardTitleNoCount => '🎟️ Recibiste créditos';

  @override
  String get creditRewardReason => 'Por ver el anuncio completo';

  @override
  String get lowCreditNoticeTitle => 'Te quedan pocos créditos';

  @override
  String get lowCreditNoticeTitleEmpty => 'Ya usaste todos tus créditos';

  @override
  String get lowCreditNoticeBody =>
      'Mira un anuncio para recibir más al momento';

  @override
  String get lowCreditNoticeAction => 'Ver anuncio';

  @override
  String get creditGuideTitle => '🎟️ Así funcionan los créditos';

  @override
  String get creditGuideBasis => 'Según tu plan';

  @override
  String get creditGuideRoutineText => 'Texto de la rutina';

  @override
  String get creditGuideCardImage => '1 imagen de tarjeta';

  @override
  String get creditGuideRegenerate => 'Volver a dibujar una imagen';

  @override
  String get creditGuideWeeklyGrant => 'Créditos cada semana';

  @override
  String get creditGuideMonthlyGrant => 'Créditos cada mes';

  @override
  String creditGuideCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count créditos',
      one: '$count crédito',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideUnlimited => 'Sin límite';

  @override
  String creditGuideRegenerateFreeToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gratis más hoy',
      one: '$count gratis más hoy',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideKeepGoing =>
      'Una rutina que empezaste se termina siempre, aunque falten créditos';

  @override
  String get creditGuideRefillWeek => 'Se recargan cada lunes a las 0:00';

  @override
  String get creditGuideRefillMonth =>
      'Se recargan el día 1 de cada mes a las 0:00';

  @override
  String creditGuideProFactBoth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Con Pro, el texto de las rutinas no tiene límite y vuelves a dibujar gratis $count veces al día',
      one:
          'Con Pro, el texto de las rutinas no tiene límite y vuelves a dibujar gratis $count vez al día',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideProFactText =>
      'Con Pro, el texto de las rutinas no tiene límite';

  @override
  String creditGuideProFactRegenerate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Con Pro vuelves a dibujar gratis $count veces al día',
      one: 'Con Pro vuelves a dibujar gratis $count vez al día',
    );
    return '$_temp0';
  }

  @override
  String creditGuideRegenerateFreeDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gratis al día',
      one: '$count gratis al día',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideConfirm => 'Entendido';

  @override
  String myCreditFreeRegenerateToday(int left, int cap) {
    return 'Volver a dibujar hoy: $left/$cap gratis';
  }

  @override
  String get myCreditRecentTitle => 'Uso reciente';

  @override
  String get myCreditSeeAllHistory => 'Ver todo';

  @override
  String get myCreditGuideLink => 'Así funcionan los créditos';

  @override
  String get abaIntroTitle => 'Fácil de preparar,\ncada día por su cuenta';

  @override
  String get abaIntroSubtitle =>
      'Basado en el Análisis Aplicado de Conducta (ABA)';

  @override
  String get abaIntroStepsTitle => 'Divide en pasos';

  @override
  String get abaIntroStepsBody => 'Tarjetas paso a paso';

  @override
  String get abaIntroShowTitle => 'Muestra antes';

  @override
  String get abaIntroShowBody => 'Con imagen y voz';

  @override
  String get abaIntroHelpTitle => 'Ayuda y retira';

  @override
  String get abaIntroHelpBody => 'Sigue por su cuenta';

  @override
  String get abaIntroRewardTitle => 'Elogia rápido';

  @override
  String get abaIntroRewardBody => 'Estrella y premio';

  @override
  String get abaIntroGuardianTitle => 'Lo más importante eres tú';

  @override
  String get abaIntroGuardianBody =>
      'Tú eliges las rutinas y las recompensas, y elum acompaña a Elumi';

  @override
  String get abaIntroStart => 'Empezar';

  @override
  String get guardianSettingsAboutElum => 'Cómo está hecho elum';

  @override
  String get notificationIntroTitle => '🔔 Activa las notificaciones';

  @override
  String get notificationIntroBody =>
      'Así te avisamos al momento y no te pierdes nada de Elumi';

  @override
  String get notificationIntroRoutineDone => 'Cuando Elumi termina una rutina';

  @override
  String get notificationIntroCaregiverRoutine =>
      'Cuando otro tutor envía una rutina';

  @override
  String get notificationIntroWeeklyReport =>
      'Cuando el informe semanal está listo';

  @override
  String get notificationIntroCreditRefilledWeek =>
      'Cuando se recargan los créditos de esta semana';

  @override
  String get notificationIntroCreditRefilledMonth =>
      'Cuando se recargan los créditos de este mes';

  @override
  String get notificationOffNoticeHighlightRoutineDone =>
      'Cuando termina una rutina';

  @override
  String get notificationOffNoticeHighlightCaregiver =>
      'Novedades de los otros tutores';

  @override
  String get notificationOffNoticeAction => 'Activar notificaciones';

  @override
  String get homeAutoSendUpsellTitle =>
      '⏰ ¿Enviar rutinas automáticamente a la misma hora cada día?';

  @override
  String get homeAutoSendUpsellBody =>
      'Elige los días y la hora, y la enviaremos al dispositivo de Elumi en ese momento';

  @override
  String get homeAutoSendUpsellAction => 'Ver más';

  @override
  String get notificationSettingRoutineNudge =>
      'Cuando aún no has enviado la rutina de hoy';

  @override
  String get notificationSettingSuggestion => 'Ideas de rutinas nuevas';

  @override
  String get notificationSettingPlanReminder =>
      'Antes de que termine tu regalo Pro';

  @override
  String get myCreditRemainingSuffix => ' restantes';
}
