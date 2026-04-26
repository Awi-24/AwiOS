import 'system_bus.dart';
import 'awi_engine_context.dart';

/// Handler para comandos system: do script .awi.
/// Recebe o evento e o contexto. Pode executar side-effects na engine.
/// Retorna true se tratou o comando; false para continuar com handlers padrão.
typedef SystemCommandHandler = void Function(SystemEvent event, AwiEngineContext ctx);

/// Registry modular de handlers para system: command(param="val", ...).
/// .awi usa system: para eventos OS (trigger, notify, unlock, set_flag, sync, etc.).
/// Novos comandos podem ser registrados sem alterar a lógica existente.
class SystemCommandRegistry {
  final Map<String, SystemCommandHandler> _handlers = {};

  /// Registra um handler para um comando.
  void register(String command, SystemCommandHandler handler) {
    _handlers[command] = handler;
  }

  /// Remove o handler de um comando.
  void unregister(String command) {
    _handlers.remove(command);
  }

  /// Executa o handler do comando, se existir.
  void execute(SystemEvent event, AwiEngineContext ctx) {
    final handler = _handlers[event.command];
    if (handler != null) {
      handler(event, ctx);
    }
  }

  /// Retorna handlers registrados (para debug).
  Iterable<String> get registeredCommands => _handlers.keys;
}

/// Handlers built-in para comandos system: do .awi.
/// Usados pelo registry padrão; podem ser sobrescritos ou estendidos.
class SystemCommandHandlers {
  static void sync(SystemEvent event, AwiEngineContext ctx) {
    if (ctx.currentChapterId != null &&
        event.path != null &&
        event.path!.isNotEmpty &&
        ctx.recordChapterPath != null) {
      ctx.recordChapterPath!(ctx.currentChapterId!, event.path!);
    }
  }

  static void unlock(SystemEvent event, AwiEngineContext ctx) {
    if (event.app == 'gallery' && event.id != null) {
      ctx.addUnlockedMedia(event.id!);
    }
  }

  static void setFlag(SystemEvent event, AwiEngineContext ctx) {
    if (event.key != null && ctx.applyToGlobalFlags != null) {
      ctx.applyToGlobalFlags!(['${event.key}=${event.value ?? 'true'}']);
    }
  }

  /// Cria registry com handlers padrão do .awi.
  static SystemCommandRegistry createDefault() {
    final registry = SystemCommandRegistry();
    registry.register('sync', sync);
    registry.register('unlock', unlock);
    registry.register('set_flag', setFlag);
    return registry;
  }
}
