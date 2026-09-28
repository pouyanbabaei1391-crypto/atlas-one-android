class AgentStep {
  final String tool;
  final String action;
  final String? target;
  final String? value;
  final bool requiresConfirmation;
  const AgentStep({required this.tool, required this.action, this.target, this.value, this.requiresConfirmation=false});
}
