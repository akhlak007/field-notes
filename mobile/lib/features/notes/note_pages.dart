import 'dart:io';

import 'package:field_notes/core/constants.dart';
import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/data/repositories/note_repository.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/customers/customer_pages.dart';
import 'package:field_notes/features/notes/note_bloc.dart';
import 'package:field_notes/features/settings/settings_bloc.dart';
import 'package:field_notes/features/sites/site_bloc.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _NotesHeader(),
            const _Filters(),
            const Expanded(child: NotesList()),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context) {
    final sites = context.read<SiteBloc>().state.sites;
    if (sites.isEmpty) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CustomersPage()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a customer and site before creating a note.'),
        ),
      );
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NoteFormPage()));
  }
}

class _NotesHeader extends StatelessWidget {
  const _NotesHeader();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NoteBloc, NoteState>(
      builder: (context, state) {
        final open = state.notes.where((note) => note.status == 'OPEN').length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: AppHeader(
            title: 'Notes',
            subtitle: state.loading
                ? 'Loading notes'
                : '${state.notes.length} notes · $open open',
            trailing: const SyncPill(),
          ),
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NoteBloc, NoteState>(
      builder: (context, state) {
        final sites = context.watch<SiteBloc>().state.sites;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                hint: 'Search title, site, customer',
                onChanged: (value) =>
                    context.read<NoteBloc>().add(NotesQueryChanged(value)),
              ),
              const SizedBox(height: 12),
              StatusPills(
                allowAll: true,
                value: state.status,
                onChanged: (value) => context.read<NoteBloc>().add(
                  NotesStatusFilterChanged(value),
                ),
              ),
              if (sites.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: state.siteId,
                  decoration: const InputDecoration(hintText: 'All sites'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All sites'),
                    ),
                    ...sites.map(
                      (site) => DropdownMenuItem<String?>(
                        value: site.id,
                        child: Text('${site.siteName} · ${site.customerName}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => context.read<NoteBloc>().add(
                    NotesSiteFilterChanged(value),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class NotesList extends StatelessWidget {
  const NotesList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NoteBloc, NoteState>(
      builder: (context, state) {
        final notes = state.notes;
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (notes.isEmpty) {
          final filtered =
              state.query.isNotEmpty ||
              state.status != null ||
              state.siteId != null;
          return EmptyState(
            icon: filtered ? Icons.search_off_rounded : Icons.note_add_outlined,
            message: filtered
                ? 'No notes match these filters.'
                : 'No field notes yet. Add a site note to get started.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              context.read<SyncBloc>().add(const SyncRequested()),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 104),
            itemCount: notes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NoteDetailPage(noteId: note.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: note.status),
                            const Spacer(),
                            Text(
                              relativeNoteTime(note.notedAt),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: appMuted(context)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          note.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${note.siteName} · ${note.customerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: appMuted(context)),
                        ),
                        if (note.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            note.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: appMuted(context)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  String? _photoPath;
  Stream<FieldNote?>? _noteStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthBloc>().state.userId;
    if (userId != null) {
      _noteStream ??= context.read<NoteRepository>().watchById(
        userId,
        widget.noteId,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhoto());
  }

  Future<void> _loadPhoto() async {
    try {
      final userId = context.read<AuthBloc>().state.userId;
      if (userId == null) return;
      final path = await context.read<NoteRepositoryHolder>().ensure(
        userId,
        widget.noteId,
      );
      if (mounted) setState(() => _photoPath = path);
    } catch (_) {
      // The note stays usable when the photo cannot be downloaded.
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthBloc>().state.userId;
    final stream = _noteStream;
    if (userId == null || stream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: const EmptyState(message: 'Sign in to view this note.'),
      );
    }
    return StreamBuilder<FieldNote?>(
      stream: stream,
      builder: (context, snapshot) {
        final note = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (note == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Note')),
            body: const EmptyState(
              message: 'This note is no longer available.',
            ),
          );
        }
        final current = note;
        final photo = _photoPath ?? current.localPhotoPath;
        final hasPhoto = photo != null && File(photo).existsSync();
        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    child: ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Back'),
                              ),
                              StatusBadge(status: current.status),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () async {
                                  final ok = await confirmDelete(
                                    context,
                                    title: 'Delete note?',
                                    message: 'This note will be removed from this device and the server.',
                                  );
                                  if (!ok || !context.mounted) return;
                                  context.read<NoteBloc>().add(
                                    NoteDeleted(current.id),
                                  );
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            current.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: hasPhoto
                                ? Image.file(
                                    File(photo),
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 180,
                                    width: double.infinity,
                                    color: const Color(0xFFD7E6E1),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Photo',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            label: 'Site',
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  current.siteName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    current.customerName,
                                    if (current.siteAddress != null &&
                                        current.siteAddress!.trim().isNotEmpty)
                                      current.siteAddress!.trim(),
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: appMuted(context)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            label: 'Details',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  current.description ??
                                      'No description added.',
                                  style: const TextStyle(height: 1.5),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  [
                                    relativeNoteTime(current.notedAt),
                                    if (current.latitude != null &&
                                        current.longitude != null)
                                      '${current.latitude}, ${current.longitude}',
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: appMuted(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              BottomBarButton(
                label: 'Edit note',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoteFormPage(note: current),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NoteRepositoryHolder {
  NoteRepositoryHolder(this.ensure);
  final Future<String?> Function(int userId, String id) ensure;
}

class NoteFormPage extends StatefulWidget {
  const NoteFormPage({super.key, this.note, this.siteId});

  final FieldNote? note;
  final String? siteId;

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late String? _siteId;
  late String _status;
  late DateTime _notedAt;
  String? _photoPath;
  int _seenTick = 0;
  int _locationTick = 0;
  int _photoTick = 0;
  String? _shownPermission;
  String? _shownError;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _title = TextEditingController(text: note?.title ?? '');
    _description = TextEditingController(text: note?.description ?? '');
    _latitude = TextEditingController(text: note?.latitude?.toString() ?? '');
    _longitude = TextEditingController(text: note?.longitude?.toString() ?? '');
    _siteId = note?.siteId ?? widget.siteId;
    _status = note?.status ?? context.read<SettingsBloc>().state.defaultStatus;
    _notedAt = note?.notedAt.toLocal() ?? DateTime.now();
    _photoPath = note?.localPhotoPath;
    final bloc = context.read<NoteBloc>().state;
    _seenTick = bloc.saveTick;
    _locationTick = bloc.locationTick;
    _photoTick = bloc.photoTick;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sites = context.watch<SiteBloc>().state.sites;
    final creating = widget.note == null;
    return BlocListener<NoteBloc, NoteState>(
      listener: (context, state) {
        if (state.saveTick != _seenTick) {
          _seenTick = state.saveTick;
          Navigator.pop(context);
          return;
        }
        if (state.locationTick != _locationTick &&
            state.latitude != null &&
            state.longitude != null) {
          _locationTick = state.locationTick;
          setState(() {
            _latitude.text = state.latitude!.toString();
            _longitude.text = state.longitude!.toString();
          });
        }
        if (state.photoTick != _photoTick && state.pickedPhotoPath != null) {
          _photoTick = state.photoTick;
          setState(() => _photoPath = state.pickedPhotoPath);
        }
        if (state.permissionMessage != null &&
            state.permissionMessage != _shownPermission) {
          _shownPermission = state.permissionMessage;
          showPermissionMessage(
            context,
            state.permissionMessage!,
            openSettings: state.openSettings,
          );
        }
        if (state.error != null && state.error != _shownError) {
          _shownError = state.error;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  child: ContentWidth(
                    maxWidth: 680,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        Text(
                          creating ? 'New note' : 'Edit note',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        const FieldLabel('Site'),
                        DropdownButtonFormField<String>(
                          initialValue: sites.any((site) => site.id == _siteId)
                              ? _siteId
                              : null,
                          decoration: const InputDecoration(
                            hintText: 'Choose a site',
                          ),
                          items: sites
                              .map(
                                (site) => DropdownMenuItem(
                                  value: site.id,
                                  child: Text(
                                    '${site.siteName} · ${site.customerName}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _siteId = value),
                        ),
                        const SizedBox(height: 14),
                        const FieldLabel('Title'),
                        AppTextField(controller: _title, hint: 'Leaking valve'),
                        const SizedBox(height: 14),
                        const FieldLabel('Description'),
                        AppTextField(
                          controller: _description,
                          hint: 'Describe what you found',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FieldLabel('Status'),
                                  DropdownButtonFormField<String>(
                                    initialValue: _status,
                                    decoration: const InputDecoration(
                                      hintText: 'Status',
                                    ),
                                    items: noteStatuses
                                        .map(
                                          (status) => DropdownMenuItem(
                                            value: status,
                                            child: Text(
                                              statusFilterLabel(status),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => _status = value ?? _status,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FieldLabel('Date & time'),
                                  TappableField(
                                    text: relativeNoteTime(_notedAt),
                                    onTap: _pickDateTime,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const FieldLabel('Location'),
                        TappableField(
                          text:
                              _latitude.text.isNotEmpty &&
                                  _longitude.text.isNotEmpty
                              ? '${_latitude.text} · ${_longitude.text}'
                              : 'Use current location',
                          muted: _latitude.text.isEmpty,
                          onTap: () => context.read<NoteBloc>().add(
                            const NoteLocationRequested(),
                          ),
                          onClear:
                              _latitude.text.isNotEmpty ||
                                  _longitude.text.isNotEmpty
                              ? () => setState(() {
                                  _latitude.clear();
                                  _longitude.clear();
                                })
                              : null,
                        ),
                        const SizedBox(height: 14),
                        const FieldLabel('Photo'),
                        if (_photoPath != null &&
                            File(_photoPath!).existsSync()) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_photoPath!),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        TappableField(
                          text: 'Camera or gallery',
                          muted: true,
                          onTap: _pickPhoto,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            BottomBarButton(
              label: creating ? 'Save note' : 'Save note',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    context.read<NoteBloc>().add(NotePhotoRequested(source));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _notedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_notedAt),
    );
    if (time == null) return;
    setState(() {
      _notedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    if (_latitude.text.trim().isNotEmpty && lat == null ||
        _longitude.text.trim().isNotEmpty && lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location must be a number.')),
      );
      return;
    }
    context.read<NoteBloc>().add(
      NoteSubmitted(
        NoteDraft(
          id: widget.note?.id,
          siteId: _siteId ?? '',
          title: _title.text,
          description: _description.text,
          latitude: _latitude.text.trim().isEmpty ? null : lat,
          longitude: _longitude.text.trim().isEmpty ? null : lng,
          notedAt: _notedAt.toUtc(),
          status: _status,
          newPhotoPath:
              _photoPath != null && _photoPath != widget.note?.localPhotoPath
              ? _photoPath
              : null,
        ),
      ),
    );
  }
}
