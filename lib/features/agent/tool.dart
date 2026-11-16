import 'intent.dart';

/// Result of running a tool: a Persian message for the UI plus optional data.
class ToolResult<T> {
  const ToolResult.ok(this.message, {this.data})
      : success = true,
        error = null;

  const ToolResult.failed(this.message, {this.error})
      : success = false,
        data = null;

  final bool success;
  final String message;
  final T? data;
  final String? error;
}

/// A capability the agent can execute, described for both the UI and a future
/// cloud planner. Tools are the *only* way the agent can change anything:
/// model output is never executed directly.
class AgentTool<T> {
  const AgentTool({
    required this.name,
    required this.title,
    required this.description,
    required this.risk,
    required this.execute,
  });

  /// Stable ASCII id, e.g. `notes.create`.
  final String name;

  /// Persian display name used in confirmation dialogs and activity history.
  final String title;
  final String description;
  final ActionRisk risk;
  final Future<ToolResult<T>> Function(Map<String, Object?> args) execute;

  /// Whether the user must confirm before the tool runs.
  bool get requiresConfirmation => risk != ActionRisk.readOnly;
}

/// Registry of the tools available in a given app state.
///
/// Deliberately small and explicit: there is no shell, no code execution and no
/// generic HTTP tool, so a compromised or confused model cannot escalate.
class ToolRegistry {
  final Map<String, AgentTool<Object?>> _tools = {};

  void register(AgentTool<Object?> tool) => _tools[tool.name] = tool;

  AgentTool<Object?>? find(String name) => _tools[name];

  List<AgentTool<Object?>> get all => List.unmodifiable(_tools.values);

  bool get isEmpty => _tools.isEmpty;
}
