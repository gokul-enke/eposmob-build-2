class SyncOperationGate {
  SyncOperationGate._();

  static final SyncOperationGate instance = SyncOperationGate._();

  Object? _owner;

  bool tryAcquire(Object owner) {
    if (_owner == null || identical(_owner, owner)) {
      _owner = owner;
      return true;
    }
    return false;
  }

  bool isOwnedBy(Object owner) => identical(_owner, owner);

  void release(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
    }
  }
}
