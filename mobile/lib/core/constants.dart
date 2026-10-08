const noteStatuses = ['OPEN', 'IN_PROGRESS', 'COMPLETED'];

String statusLabel(String status) {
  switch (status) {
    case 'IN_PROGRESS':
      return 'In progress';
    case 'COMPLETED':
      return 'Completed';
    default:
      return 'Open';
  }
}

String statusFilterLabel(String status) {
  switch (status) {
    case 'IN_PROGRESS':
      return 'In progress';
    case 'COMPLETED':
      return 'Done';
    default:
      return 'Open';
  }
}

class SyncStates {
  static const synced = 'synced';
  static const pendingUpsert = 'pending_upsert';
  static const pendingDelete = 'pending_delete';
}

class PhotoSync {
  static const none = 'none';
  static const pendingUpload = 'pending_upload';
  static const synced = 'synced';
}
