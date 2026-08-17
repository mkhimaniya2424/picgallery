import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../repositories/media_repository.dart';
import '../providers/media_provider.dart';
import '../services/media_picker_service.dart' show MediaContentType;
import '../storage/upload_queue_local_store.dart';

import 'upload_job_model.dart';
import 'upload_media_prep.dart';
import 'upload_network_gate.dart';
import 'upload_queue_state.dart';

/// Controller/notifier for the Upload Queue.
///
/// Task 19.11: progress bars are now driven by the real
/// `onSendProgress(sent, total)` callback from [MediaRepository.uploadMedia]
/// (`MediaUploadService` under the hood, Task 19.5/19.9) instead of a
/// time-based simulation. A queued job's real upload — file read + network
/// request — kicks off the moment it's picked off the queue, and every
/// progress tick from the socket is written straight onto that job's
/// `uploadedBytes`/`totalBytes`, so the tile the user sees
/// ([UploadQueueTile]) reflects bytes actually in flight, not a guess.
/// Options configuration, pausing/resuming/cancelling, Hive storage, and
/// automated refresh of the gallery/media providers are unchanged.
class UploadQueueController extends AsyncNotifier<UploadQueueState> {
  Timer? _ticker;

  /// Read fresh each time rather than cached in a field — this queue can
  /// outlive a single repository instance (e.g. `apiClientProvider`
  /// rebuilding), and always going through Riverpod keeps this on the
  /// same API-backed [MediaRepository] (Task 19.9) as the rest of the
  /// app instead of a hardcoded local one.
  MediaRepository get _mediaRepo => ref.read(mediaRepositoryProvider);

  final UploadQueueLocalStore _localStore = UploadQueueLocalStore();

  /// Id of the job whose real upload (file read + network request) is
  /// currently in flight. Only one real upload runs at a time — this guards
  /// against the ticker starting a second one for the same slot while the
  /// first is still awaiting bytes on the wire, including in the moment a
  /// job goes from `uploading` to `paused`/`canceled` (which can't actually
  /// abort an in-flight `package:http` request — see [_beginRealUpload]).
  String? _inFlightJobId;

  /// Snapshot of total uploaded bytes across all jobs as of the last tick,
  /// used only to derive a real bytes/sec speed reading for display.
  int _lastTickTotalUploadedBytes = 0;

  /// Task 19.12 — offline-upload queueing.
  ///
  /// Runs independently of [_ticker] (which only exists while something is
  /// actively queued/uploading) so a job that failed because the device
  /// was offline keeps getting retried in the background even if the user
  /// never reopens the upload screen. Backoff intervals below are indexed
  /// by [UploadJobModel.offlineRetryCount] (clamped to the last entry) so
  /// a genuinely offline device isn't hammered with requests every few
  /// seconds.
  static const List<int> _offlineBackoffSeconds = [5, 15, 30, 60, 120];

  Timer? _offlineRetryTicker;

  // Simulated cellular flag to check WiFi-only option
  bool _simulateCellular = false;
  bool get simulateCellular => _simulateCellular;

  @override
  FutureOr<UploadQueueState> build() async {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
      _offlineRetryTicker?.cancel();
      _offlineRetryTicker = null;
    });

    // Task 19.12: poll for jobs that failed because the device looked
    // offline and requeue them once their backoff window has passed —
    // this runs for the controller's whole lifetime, not just while the
    // wizard's Progress step is open, since a job can go offline-pending
    // long after the user has left that screen.
    _offlineRetryTicker ??=
        Timer.periodic(const Duration(seconds: 5), (_) => _tickOfflineRetries());

    // Load from Hive database
    final persistedJobs = await _localStore.load();

    // Sanitize any stuck jobs from a previous launch
    final sanitizedJobs = persistedJobs.map((j) {
      if (j.status == UploadJobStatus.uploading) {
        return j.copyWith(status: UploadJobStatus.paused);
      }
      return j;
    }).toList();

    // If there are unfinished jobs, we start in step 2 (Progress) so user can see them
    final hasUnfinished = sanitizedJobs.any((j) => !j.isDone);

    return UploadQueueState(
      jobs: sanitizedJobs,
      isProcessing: false,
      wizardStep: hasUnfinished ? 2 : 0,
    );
  }

  void toggleSimulationNetwork() {
    _simulateCellular = !_simulateCellular;
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      message: _simulateCellular
          ? "Simulating: Cellular Data active"
          : "Simulating: Wi-Fi active",
    ));
    // If ticker is active, it will automatically pause wifi-only jobs next tick
    if (_ticker == null && !_simulateCellular) {
      _ensureProcessing();
    }
  }

  Future<void> _refreshMediaGrid() async {
    try {
      final controller = ref.read(mediaProvider);
      await controller.load();
    } catch (_) {
      // ignore if provider not fully setup in test
    }
  }

  // Wizard transitions
  void setWizardStep(int step) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(wizardStep: step));
  }

  void updatePickedFiles(List<PlatformFile> files) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(tempPickedFiles: files));
  }

  void removePickedFileAt(int index) {
    final current = state.value;
    if (current == null) return;
    final files = [...current.tempPickedFiles];
    files.removeAt(index);
    state = AsyncValue.data(current.copyWith(tempPickedFiles: files));
  }

  void clearPickedFiles() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      tempPickedFiles: const [],
      wizardStep: 0,
      clearAlbum: true,
      clearFolder: true,
      clearRenamePrefix: true,
    ));
  }

  void updateOptions({
    String? albumId,
    bool clearAlbum = false,
    String? folderId,
    bool clearFolder = false,
    String? renamePrefix,
    bool clearRenamePrefix = false,
    bool? compress,
    bool? wifiOnly,
    bool? keepOriginalQuality,
    bool? uploadMetadata,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      selectedAlbumId: clearAlbum ? null : (albumId ?? current.selectedAlbumId),
      selectedFolderId:
          clearFolder ? null : (folderId ?? current.selectedFolderId),
      renamePrefix:
          clearRenamePrefix ? null : (renamePrefix ?? current.renamePrefix),
      compress: compress ?? current.compress,
      wifiOnly: wifiOnly ?? current.wifiOnly,
      keepOriginalQuality: keepOriginalQuality ?? current.keepOriginalQuality,
      uploadMetadata: uploadMetadata ?? current.uploadMetadata,
    ));
  }

  Future<void> _saveQueue() async {
    final current = state.value;
    if (current == null) return;
    await _localStore.saveAll(current.jobs);
  }

  /// Add picked files to the persistent queue and start the uploading process
  Future<void> startUpload() async {
    final current = state.value;
    if (current == null || current.tempPickedFiles.isEmpty) return;

    final List<UploadJobModel> newJobs = [];
    final prefix = current.renamePrefix?.trim() ?? '';

    for (int i = 0; i < current.tempPickedFiles.length; i++) {
      final f = current.tempPickedFiles[i];
      final originalName = f.name.isNotEmpty ? f.name : 'untitled_${i + 1}';

      // Rename handling
      String finalName = originalName;
      if (prefix.isNotEmpty) {
        final dotIdx = originalName.lastIndexOf('.');
        final ext = (dotIdx != -1) ? originalName.substring(dotIdx) : '';
        finalName = current.tempPickedFiles.length == 1
            ? '$prefix$ext'
            : '$prefix (${i + 1})$ext';
      }

      // `f.path` isn't just null on web — touching the getter itself
      // throws — so it has to stay behind a `kIsWeb` check rather than
      // a `?? ''`. Web instead carries its bytes through [webBytes],
      // captured once here since a browser can't re-read a path later.
      newJobs.add(UploadJobModel(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        fileName: finalName,
        filePath: kIsWeb ? '' : (f.path ?? ''),
        webBytes: kIsWeb ? f.bytes : null,
        albumId: current.selectedAlbumId,
        folderId: current.selectedFolderId,
        totalBytes: f.size > 0 ? f.size : 1024 * 1024 * 5, // Default to 5MB
        uploadedBytes: 0,
        createdAt: DateTime.now(),
        status: UploadJobStatus.queued,
        compress: current.compress,
        wifiOnly: current.wifiOnly,
        keepOriginalQuality: current.keepOriginalQuality,
        uploadMetadata: current.uploadMetadata,
      ));
    }

    state = AsyncValue.data(current.copyWith(
      jobs: [...current.jobs, ...newJobs],
      tempPickedFiles: const [],
      wizardStep: 2, // Navigates to Progress view
      message: 'Uploading ${newJobs.length} item(s)',
    ));

    await _saveQueue();
    _ensureProcessing();
  }

  void _ensureProcessing() {
    if (state.value?.isProcessing == true) return;

    final current = state.value;
    if (current == null) return;
    if (current.jobs.every(
        (j) => j.isDone || j.status == UploadJobStatus.paused)) return;

    state = AsyncValue.data(
      current.copyWith(isProcessing: true, clearMessage: true),
    );

    _ticker?.cancel();

    _lastTickTotalUploadedBytes =
        current.jobs.fold<int>(0, (sum, j) => sum + j.uploadedBytes);

    // Ticks every 250ms. It no longer invents progress — its job is now
    // just to (a) pick the next queued file and hand it to
    // [_beginRealUpload], which drives that job's bytes off the real
    // `onSendProgress` callback, and (b) derive a speed/ETA reading from
    // how those real bytes moved between ticks, for display only.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      final s = state.value;
      if (s == null) return;

      // Task 4: real, device-level Wi-Fi-only enforcement driven by the
      // global `settings.wifiOnlyUploads` toggle — checked once per tick
      // and reused below for both "start the next queued job" and
      // "pause anything already uploading" so a network drop mid-upload
      // is caught too, not just at start time.
      final gate = await canUploadNow(ref);

      final anyUploading =
          s.jobs.any((j) => j.status == UploadJobStatus.uploading);
      final hasQueued = s.jobs.any((j) => j.status == UploadJobStatus.queued);

      // Only ever one real upload in flight at a time.
      if (_inFlightJobId == null && !anyUploading && hasQueued) {
        final idx = s.jobs.indexWhere((j) => j.status == UploadJobStatus.queued);
        if (idx != -1) {
          final job = s.jobs[idx];

          final blockedBySimulation = job.wifiOnly && _simulateCellular;
          final blockedByRealGate = !gate.canUpload;

          if (blockedBySimulation || blockedByRealGate) {
            // Block and queue the job instead of silently uploading over
            // mobile data — either the per-batch WiFi-only option was
            // tripped by the dev "simulate cellular" toggle, or the
            // global Settings > Wi-Fi Only Uploads gate found no real
            // Wi-Fi connection right now.
            final updatedJobs = [...s.jobs];
            updatedJobs[idx] = job.copyWith(
              status: UploadJobStatus.paused,
              errorMessage: blockedBySimulation
                  ? "Paused: WiFi required (on Cellular Network)"
                  : (gate.reason ?? "Waiting for Wi-Fi to upload"),
            );
            state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
            await _saveQueue();
          } else {
            // Fire-and-forget: this runs the real file read + network
            // request and updates state itself via onSendProgress as it
            // goes, independently of this timer tick.
            unawaited(_beginRealUpload(job));
          }
        }
      }

      // Cellular network check mid-upload — same caveat as pause/cancel:
      // this can't abort bytes already handed to `package:http`, only
      // update what the UI shows for a job that hasn't finished yet.
      if (_simulateCellular || !gate.canUpload) {
        final blocked = s.jobs.where((j) =>
            j.status == UploadJobStatus.uploading &&
            (j.wifiOnly || !gate.canUpload));
        if (blocked.isNotEmpty) {
          final updatedJobs = s.jobs.map((j) {
            if (j.status == UploadJobStatus.uploading &&
                (j.wifiOnly || !gate.canUpload)) {
              return j.copyWith(
                status: UploadJobStatus.paused,
                errorMessage: (!gate.canUpload && (gate.reason != null))
                    ? gate.reason!
                    : "Paused: WiFi required (on Cellular Network)",
              );
            }
            return j;
          }).toList();
          state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
          await _saveQueue();
        }
      }

      // Derive a real bytes/sec reading from how far uploadedBytes moved
      // across all jobs since the last tick (tick = 250ms, so *4 for /sec).
      final refreshed = state.value ?? s;
      final totalUploadedNow =
          refreshed.jobs.fold<int>(0, (sum, j) => sum + j.uploadedBytes);
      final stillActive = refreshed.jobs.any((j) =>
          j.status == UploadJobStatus.uploading ||
          j.status == UploadJobStatus.queued);
      final deltaBytes = totalUploadedNow - _lastTickTotalUploadedBytes;
      _lastTickTotalUploadedBytes = totalUploadedNow;
      final currentSpeed =
          stillActive && deltaBytes > 0 ? (deltaBytes * 4).toDouble() : 0.0;

      Duration? estRemaining;
      if (currentSpeed > 0) {
        int remainingBytes = 0;
        for (final j in refreshed.jobs) {
          if (j.status == UploadJobStatus.uploading ||
              j.status == UploadJobStatus.queued) {
            remainingBytes += (j.totalBytes - j.uploadedBytes);
          }
        }
        if (remainingBytes > 0) {
          final seconds = remainingBytes / currentSpeed;
          estRemaining = Duration(seconds: seconds.ceil());
        }
      }

      state = AsyncValue.data(refreshed.copyWith(
        isProcessing: stillActive,
        speedBytesPerSecond: stillActive ? currentSpeed : 0.0,
        remainingTime: stillActive ? estRemaining : null,
        clearRemainingTime: !stillActive,
      ));

      if (!stillActive) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  /// Starts the real upload for [job]: reads its bytes off disk and sends
  /// them to the API-backed repository, wiring [MediaRepository.uploadMedia]'s
  /// `onSendProgress(sent, total)` straight onto that job's
  /// `uploadedBytes`/`totalBytes` (Task 19.11) so [UploadQueueTile]'s
  /// progress bar reflects bytes actually on the wire — not a guess.
  Future<void> _beginRealUpload(UploadJobModel job) async {
    _inFlightJobId = job.id;

    final started = state.value;
    if (started == null) {
      _inFlightJobId = null;
      return;
    }
    final startedJobs = started.jobs.map((j) {
      if (j.id != job.id) return j;
      return j.copyWith(
        status: UploadJobStatus.uploading,
        startedAt: DateTime.now(),
        clearError: true,
      );
    }).toList();
    state = AsyncValue.data(started.copyWith(jobs: startedJobs));
    await _saveQueue();

    try {
      // `dart:io.File` doesn't exist on web at all, so a stored path is
      // useless there — read from the bytes captured at pick time
      // instead (see `UploadJobModel.webBytes`). If they're gone (e.g.
      // the job survived a page reload, which drops in-memory state),
      // that's the same "can't get at this file anymore" situation as a
      // moved/deleted file on mobile — surface it the same way below.
      final bytes = kIsWeb
          ? job.webBytes
          : await File(job.filePath).readAsBytes();
      if (bytes == null) {
        throw StateError('No bytes available for this file');
      }

      final contentType = MediaContentType.forFileName(job.fileName);

      // Task 5: honor the global "Upload Resolution" setting (Settings >
      // Original/High) — same [prepareMediaBytesForUpload] helper the
      // single-file uploader uses, so "High" compresses photos to
      // ~2048px long edge / JPEG quality 85 consistently regardless of
      // which upload path a file went through.
      final preparedBytes = await prepareMediaBytesForUpload(
        ref,
        bytes: bytes,
        contentType: contentType,
      );

      await _mediaRepo.uploadMedia(
        bytes: preparedBytes,
        fileName: job.fileName,
        contentType: contentType,
        albumId: job.albumId,
        folderId: job.folderId,
        onSendProgress: (sent, total) => _onRealProgress(job.id, sent, total),
      );
      await _onRealSuccess(job.id);
    } on ApiException catch (e) {
      // `MediaUploadService`/`ApiClient` both use statusCode 0 specifically
      // for "never reached the server" — DNS failure, connection refused,
      // timeout — as opposed to a real HTTP response the server sent back
      // (400/401/413/etc). That's exactly the "offline" case Task 19.12
      // covers; anything else is a genuine rejection retrying won't fix.
      await _onRealFailure(job.id, e.message,
          isConnectivityIssue: e.statusCode == 0);
    } catch (_) {
      // File missing/moved, permission error, etc. — not connectivity, so
      // don't auto-retry; the file itself needs the user's attention.
      await _onRealFailure(job.id,
          "Couldn't read this file to upload it — it may have been moved or deleted.");
    } finally {
      _inFlightJobId = null;
    }
  }

  /// Called by the real `onSendProgress` callback, potentially many times
  /// a second, while [jobId]'s upload is on the wire.
  void _onRealProgress(String jobId, int sent, int total) {
    final s = state.value;
    if (s == null) return;
    final idx = s.jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final job = s.jobs[idx];
    // The user paused/canceled this job's *UI* state, but package:http
    // has no cancellation token, so the request already in flight can't
    // actually be aborted. Stop reflecting its progress once it's no
    // longer "uploading" so the tile doesn't fight the state the user
    // asked for; _onRealSuccess/_onRealFailure below still reconcile
    // once the request actually finishes.
    if (job.status != UploadJobStatus.uploading) return;

    final updatedJobs = [...s.jobs];
    updatedJobs[idx] = job.copyWith(
      uploadedBytes: sent,
      totalBytes: total > 0 ? total : job.totalBytes,
    );
    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
  }

  Future<void> _onRealSuccess(String jobId) async {
    final s = state.value;
    if (s == null) return;
    final idx = s.jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final job = s.jobs[idx];
    // A cancel can't retract bytes that already reached the server, but
    // it can at least keep the local queue honoring the user's intent
    // instead of flipping a canceled row back to "completed".
    if (job.status == UploadJobStatus.canceled) return;

    final updatedJobs = [...s.jobs];
    updatedJobs[idx] = job.copyWith(
      status: UploadJobStatus.completed,
      uploadedBytes: job.totalBytes,
      finishedAt: DateTime.now(),
      clearError: true,
    );

    final stillActive = updatedJobs.any((j) =>
        j.status == UploadJobStatus.uploading ||
        j.status == UploadJobStatus.queued);

    state = AsyncValue.data(s.copyWith(
      jobs: updatedJobs,
      // Auto go to the Success/Complete screen (step 3) once nothing is
      // left uploading or queued.
      wizardStep: (!stillActive && s.wizardStep == 2) ? 3 : s.wizardStep,
    ));
    await _saveQueue();

    // Auto-refresh the Gallery provider — a real row now exists
    // server-side for this job.
    await _refreshMediaGrid();
  }

  Future<void> _onRealFailure(String jobId, String message,
      {bool isConnectivityIssue = false}) async {
    final s = state.value;
    if (s == null) return;
    final idx = s.jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final job = s.jobs[idx];
    if (job.status == UploadJobStatus.canceled) return;

    final updatedJobs = [...s.jobs];
    if (isConnectivityIssue) {
      final backoffIdx = job.offlineRetryCount < _offlineBackoffSeconds.length
          ? job.offlineRetryCount
          : _offlineBackoffSeconds.length - 1;
      final backoff = _offlineBackoffSeconds[backoffIdx];
      updatedJobs[idx] = job.copyWith(
        status: UploadJobStatus.failed,
        errorMessage:
            "No connection — will retry automatically once you're back online.",
        offlinePending: true,
        offlineRetryCount: job.offlineRetryCount + 1,
        nextRetryAt: DateTime.now().add(Duration(seconds: backoff)),
      );
    } else {
      // A real server-side rejection (bad content type, 413, 401, a
      // missing/unreadable file, etc.) — retrying blindly won't help, so
      // this stays a plain failure the user resolves with a manual Retry.
      updatedJobs[idx] = job.copyWith(
        status: UploadJobStatus.failed,
        errorMessage: message,
        offlinePending: false,
        offlineRetryCount: 0,
        clearNextRetryAt: true,
      );
    }
    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
    await _saveQueue();
  }

  /// Task 19.12: requeues any job whose last failure looked like a
  /// connectivity problem and whose backoff window has passed. Requeuing
  /// just flips it back to `queued` and calls [_ensureProcessing] — the
  /// normal upload path (and [_beginRealUpload]'s real `onSendProgress`
  /// hookup from Task 19.11) takes it from there, same as if the user had
  /// tapped Retry by hand.
  Future<void> _tickOfflineRetries() async {
    final s = state.value;
    if (s == null) return;

    final now = DateTime.now();
    final dueJobIds = s.jobs
        .where((j) =>
            j.status == UploadJobStatus.failed &&
            j.offlinePending &&
            (j.nextRetryAt == null || !now.isBefore(j.nextRetryAt!)))
        .map((j) => j.id)
        .toSet();
    if (dueJobIds.isEmpty) return;

    final updatedJobs = s.jobs.map((j) {
      if (!dueJobIds.contains(j.id)) return j;
      return j.copyWith(
        status: UploadJobStatus.queued,
        clearError: true,
        clearNextRetryAt: true,
      );
    }).toList();

    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
    await _saveQueue();
    _ensureProcessing();
  }

  Future<void> pauseJob(String jobId) async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.id != jobId) return j;
      if (j.isDone) return j;
      return j.copyWith(
        status: UploadJobStatus.paused,
        errorMessage: "Paused by user",
      );
    }).toList();

    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
    await _saveQueue();

    if (updatedJobs
        .every((j) => j.isDone || j.status == UploadJobStatus.paused)) {
      _ticker?.cancel();
      _ticker = null;
      state = AsyncValue.data(s.copyWith(
        jobs: updatedJobs,
        isProcessing: false,
        speedBytesPerSecond: 0.0,
        remainingTime: null,
      ));
    }
  }

  Future<void> resumeJob(String jobId) async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.id != jobId) return j;
      if (j.status != UploadJobStatus.paused) return j;
      return j.copyWith(
        status: UploadJobStatus.queued,
        clearError: true,
      );
    }).toList();

    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
    await _saveQueue();
    _ensureProcessing();
  }

  Future<void> pauseAll() async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.isDone) return j;
      return j.copyWith(
        status: UploadJobStatus.paused,
        errorMessage: "Paused by user",
      );
    }).toList();

    _ticker?.cancel();
    _ticker = null;

    state = AsyncValue.data(s.copyWith(
      jobs: updatedJobs,
      isProcessing: false,
      speedBytesPerSecond: 0.0,
      remainingTime: null,
    ));
    await _saveQueue();
  }

  Future<void> resumeAll() async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.status != UploadJobStatus.paused) return j;
      return j.copyWith(
        status: UploadJobStatus.queued,
        clearError: true,
      );
    }).toList();

    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
    await _saveQueue();
    _ensureProcessing();
  }

  Future<void> cancelJob(String jobId) async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.id != jobId) return j;
      if (j.isDone) return j;
      return j.copyWith(
        status: UploadJobStatus.canceled,
        finishedAt: DateTime.now(),
      );
    }).toList();

    state = AsyncValue.data(s.copyWith(
      jobs: updatedJobs,
      message: 'Canceled upload',
    ));
    await _saveQueue();

    if (updatedJobs.every((j) => j.isDone)) {
      _ticker?.cancel();
      _ticker = null;
      state = AsyncValue.data(state.value!.copyWith(
        isProcessing: false,
        speedBytesPerSecond: 0.0,
        remainingTime: null,
      ));
    }
  }

  Future<void> cancelAll() async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.isDone) return j;
      return j.copyWith(
        status: UploadJobStatus.canceled,
        finishedAt: DateTime.now(),
      );
    }).toList();

    _ticker?.cancel();
    _ticker = null;

    state = AsyncValue.data(s.copyWith(
      jobs: updatedJobs,
      isProcessing: false,
      speedBytesPerSecond: 0.0,
      remainingTime: null,
      message: 'Canceled all uploads',
    ));
    await _saveQueue();
  }

  /// Manual retry for a single job — this is what the per-tile Retry
  /// button calls (Task 19.12 also fixes that button: it previously
  /// called `resumeJob`, which only acts on `paused` jobs and so silently
  /// did nothing for a `failed` one).
  Future<void> retryJob(String jobId) async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.id != jobId || j.status != UploadJobStatus.failed) return j;
      return j.copyWith(
        status: UploadJobStatus.queued,
        uploadedBytes: 0,
        clearError: true,
        offlinePending: false,
        offlineRetryCount: 0,
        clearNextRetryAt: true,
      );
    }).toList();

    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
    await _saveQueue();
    _ensureProcessing();
  }

  Future<void> retryFailed() async {
    final s = state.value;
    if (s == null) return;

    final updatedJobs = s.jobs.map((j) {
      if (j.status != UploadJobStatus.failed) return j;
      return j.copyWith(
        status: UploadJobStatus.queued,
        uploadedBytes: 0,
        clearError: true,
        offlinePending: false,
        offlineRetryCount: 0,
        clearNextRetryAt: true,
      );
    }).toList();

    state = AsyncValue.data(s.copyWith(jobs: updatedJobs));
    await _saveQueue();
    _ensureProcessing();
  }

  Future<void> clearCompleted() async {
    final s = state.value;
    if (s == null) return;

    final remainingJobs = s.jobs.where((j) => !j.isDone).toList();
    state = AsyncValue.data(s.copyWith(jobs: remainingJobs));
    await _saveQueue();
  }

  Future<void> resetWizard() async {
    final s = state.value;
    if (s == null) return;

    state = AsyncValue.data(s.copyWith(
      wizardStep: 0,
      tempPickedFiles: const [],
      clearAlbum: true,
      clearFolder: true,
      clearRenamePrefix: true,
    ));
  }

  Future<void> failFirstNonDone() async {
    final s = state.value;
    if (s == null) return;

    final idx = s.jobs.indexWhere((j) => !j.isDone);
    if (idx == -1) return;

    final updated = [...s.jobs];
    final j = updated[idx];
    updated[idx] = j.copyWith(
      status: UploadJobStatus.failed,
      finishedAt: DateTime.now(),
      errorMessage: 'Simulated connection failure',
    );

    state = AsyncValue.data(s.copyWith(
      jobs: updated,
      message: 'Upload failed (simulated)',
    ));
    await _saveQueue();

    if (updated.every((j) => j.isDone)) {
      _ticker?.cancel();
      _ticker = null;
      state = AsyncValue.data(state.value!.copyWith(
        isProcessing: false,
        speedBytesPerSecond: 0.0,
        remainingTime: null,
      ));
    }
  }
}

final uploadQueueProvider =
    AsyncNotifierProvider<UploadQueueController, UploadQueueState>(
  () => UploadQueueController(),
);
