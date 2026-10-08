import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/data/repositories/note_repository.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/customers/customer_bloc.dart';
import 'package:field_notes/features/notes/note_pages.dart';
import 'package:field_notes/features/sites/site_bloc.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SiteList extends StatelessWidget {
  const SiteList({super.key, required this.customerId, this.contactInfo});

  final String customerId;
  final String? contactInfo;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SiteBloc, SiteState>(
      builder: (context, state) {
        final sites = state.sites
            .where((site) => site.customerId == customerId)
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
          children: [
            if (contactInfo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  label: 'Contact',
                  child: Text(contactInfo!),
                ),
              ),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sites.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: EmptyState(message: 'No sites for this customer yet.'),
              )
            else
              ...sites.map(
                (site) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SiteDetailPage(siteId: site.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              site.siteName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              site.address ?? 'No address added',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SiteDetailPage extends StatelessWidget {
  const SiteDetailPage({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SiteBloc, SiteState>(
      builder: (context, state) {
        Site? site;
        for (final item in state.sites) {
          if (item.id == siteId) site = item;
        }
        if (site == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Site')),
            body: const EmptyState(
              message: 'This site is no longer available.',
            ),
          );
        }
        final current = site;
        return Scaffold(
          appBar: AppBar(
            title: Text(current.siteName),
            actions: [
              IconButton(
                tooltip: 'Edit',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SiteFormPage(site: current),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () async {
                  final ok = await confirmDelete(
                    context,
                    title: 'Delete site?',
                    message: 'This will also delete this site\'s notes.',
                  );
                  if (!ok || !context.mounted) return;
                  context.read<SiteBloc>().add(SiteDeleted(current.id));
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoteFormPage(siteId: current.id),
              ),
            ),
            child: const Icon(Icons.add),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SectionCard(
                  label: 'Customer',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.customerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current.address ?? 'No address',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: SiteNotes(siteId: current.id)),
            ],
          ),
        );
      },
    );
  }
}

class SiteFormPage extends StatefulWidget {
  const SiteFormPage({super.key, this.site, this.customerId});

  final Site? site;
  final String? customerId;

  @override
  State<SiteFormPage> createState() => _SiteFormPageState();
}

class _SiteFormPageState extends State<SiteFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late String? _customerId;
  int _seenTick = 0;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.site?.siteName ?? '');
    _address = TextEditingController(text: widget.site?.address ?? '');
    _customerId = widget.site?.customerId ?? widget.customerId;
    _seenTick = context.read<SiteBloc>().state.saveTick;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthBloc>().state.userId;
    final customers = context.watch<CustomerBloc>().state.customers;
    final creating = widget.site == null;
    return BlocListener<SiteBloc, SiteState>(
      listenWhen: (previous, current) =>
          current.saveTick != _seenTick || current.error != previous.error,
      listener: (context, state) {
        if (state.saveTick != _seenTick) {
          Navigator.pop(context);
          return;
        }
        if (state.error != null) {
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
                    maxWidth: 640,
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
                          creating ? 'New site' : 'Edit site',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        const FieldLabel('Customer'),
                        DropdownButtonFormField<String>(
                          initialValue:
                              customers.any(
                                (customer) => customer.id == _customerId,
                              )
                              ? _customerId
                              : null,
                          decoration: const InputDecoration(
                            hintText: 'Choose a customer',
                          ),
                          items: customers
                              .map(
                                (customer) => DropdownMenuItem(
                                  value: customer.id,
                                  child: Text(customer.name),
                                ),
                              )
                              .toList(),
                          onChanged:
                              widget.customerId == null && widget.site == null
                              ? (value) => setState(() => _customerId = value)
                              : null,
                        ),
                        const SizedBox(height: 14),
                        const FieldLabel('Site name'),
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            hintText: 'Site name',
                          ),
                        ),
                        const SizedBox(height: 14),
                        const FieldLabel('Address'),
                        TextField(
                          controller: _address,
                          decoration: const InputDecoration(
                            hintText: 'Address',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            BottomBarButton(
              label: 'Save',
              onPressed: userId == null
                  ? null
                  : () => context.read<SiteBloc>().add(
                      SiteSubmitted(
                        id: widget.site?.id,
                        userId: userId,
                        customerId: _customerId ?? '',
                        siteName: _name.text,
                        address: _address.text,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SiteNotes extends StatelessWidget {
  const SiteNotes({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthBloc>().state.userId;
    if (userId == null) return const SizedBox.shrink();
    return StreamBuilder<List<FieldNote>>(
      stream: context.read<NoteRepository>().watch(
        userId: userId,
        siteId: siteId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snapshot.data ?? const <FieldNote>[];
        if (notes.isEmpty) {
          return const EmptyState(
            icon: Icons.note_add_outlined,
            message: 'No notes for this site yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 104),
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
                      StatusBadge(status: note.status),
                      const SizedBox(height: 10),
                      Text(
                        note.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
