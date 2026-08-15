import 'package:flutter/material.dart';



import 'media_copy_move_flow_screen.dart';

class MediaBatchWorkflows {
  static Future<void> openMove({
    required BuildContext context,
    required List<String> mediaIds,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaCopyMoveFlowScreen(
          args: MediaBatchActionArgs(
              action: MediaBatchAction.move, mediaIds: mediaIds),
        ),
      ),
    );
  }

  static Future<void> openCopy({
    required BuildContext context,
    required List<String> mediaIds,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaCopyMoveFlowScreen(
          args: MediaBatchActionArgs(
              action: MediaBatchAction.copy, mediaIds: mediaIds),
        ),
      ),
    );
  }
}
