/// Service to manage dialog state and prevent multiple dialogs from opening
class DialogManager {
  static final DialogManager _instance = DialogManager._internal();
  factory DialogManager() => _instance;
  DialogManager._internal();

  bool _isWordDetailDialogOpen = false;

  /// Check if word detail dialog is currently open
  bool get isWordDetailDialogOpen => _isWordDetailDialogOpen;

  /// Mark word detail dialog as open
  void setWordDetailDialogOpen(bool isOpen) {
    _isWordDetailDialogOpen = isOpen;
  }

  /// Check if we can open a new word detail dialog
  bool canOpenWordDetailDialog() {
    return !_isWordDetailDialogOpen;
  }
}

