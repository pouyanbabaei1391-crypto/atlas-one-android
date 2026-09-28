class ToolResult {
  final bool ok;
  final String message;
  final String observation;
  const ToolResult(this.ok, this.message, {this.observation=''});
}
