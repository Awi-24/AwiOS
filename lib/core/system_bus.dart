import 'dart:async';

/// Evento disparado pelo barramento de sistema (system: no script).
class SystemEvent {
  final String command;
  final Map<String, String> params;

  const SystemEvent({required this.command, required this.params});

  String? get app => params['app'];
  String? get action => params['action'];
  String? get id => params['id'];
  String? get key => params['key'];
  String? get value => params['value'];
  String? get title => params['title'];
  String? get body => params['body'];
  String? get avatar => params['avatar'];
  String? get chapter => params['chapter'];
  String? get path => params['path'];
  String? get media => params['media'];

  @override
  String toString() => 'SystemEvent($command, $params)';
}

/// Barramento de sistema: recebe eventos e distribui para apps.
/// Scripts .awi disparam via system: trigger(...), unlock(...), etc.
class SystemBus {
  SystemBus._();

  static final StreamController<SystemEvent> _controller =
      StreamController<SystemEvent>.broadcast();

  /// Stream de eventos do sistema.
  static Stream<SystemEvent> get events => _controller.stream;

  /// Emite um evento (usado pela engine ao processar system:).
  static void emit(SystemEvent event) {
    _controller.add(event);
  }

  /// Emite evento de trigger (adiciona conteúdo a outro app).
  static void trigger({required String app, required String action, required String id}) {
    emit(SystemEvent(
      command: 'trigger',
      params: {'app': app, 'action': action, 'id': id},
    ));
  }

  /// Emite evento de unlock (libera mídia em outro app).
  static void unlock({required String app, required String id}) {
    emit(SystemEvent(
      command: 'unlock',
      params: {'app': app, 'id': id},
    ));
  }

  /// Emite evento de notify (popup de notificação).
  static void notify({required String title, required String body, required String app}) {
    emit(SystemEvent(
      command: 'notify',
      params: {'title': title, 'body': body, 'app': app},
    ));
  }

  /// Emite evento de toast (caixa que desliza do topo). Sistema separado, acionado pelo .awi.
  static void toast({required String title, String body = ''}) {
    emit(SystemEvent(
      command: 'toast',
      params: {'title': title, 'body': body},
    ));
  }

  /// Emite evento de set_flag (altera estado global).
  static void setFlag({required String key, required String value}) {
    emit(SystemEvent(
      command: 'set_flag',
      params: {'key': key, 'value': value},
    ));
  }

  /// Emite evento de sync (grava path no histórico).
  static void sync({required String chapter, required String path}) {
    emit(SystemEvent(
      command: 'sync',
      params: {'chapter': chapter, 'path': path},
    ));
  }

  /// Emite evento de os_lock (bloqueia navegação).
  static void osLock({bool navigation = true}) {
    emit(SystemEvent(
      command: 'os_lock',
      params: {'navigation': navigation.toString()},
    ));
  }

  /// Fecha o barramento (cleanup).
  static Future<void> close() => _controller.close();
}
