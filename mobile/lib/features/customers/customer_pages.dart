import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/customers/customer_bloc.dart';
import 'package:field_notes/features/sites/site_bloc.dart';
import 'package:field_notes/features/sites/site_pages.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CustomerFormPage())),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: AppHeader(
                title: 'Customers',
                trailing: SyncPill(),
              ),
            ),
            Expanded(
              child: BlocBuilder<CustomerBloc, CustomerState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.customers.isEmpty) {
                    return EmptyState(
                      icon: Icons.domain_add_outlined,
                      message:
                          'No customers yet. Add the customer for a site visit.',
                      actionLabel: 'Add customer',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerFormPage(),
                        ),
                      ),
                    );
                  }
                  final sites = context.watch<SiteBloc>().state.sites;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 104),
                    itemCount: state.customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = state.customers[index];
                      final count = sites
                          .where((site) => site.customerId == customer.id)
                          .length;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerDetailPage(customerId: customer.id),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        customer.contactInfo ??
                                            'No contact information',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                SiteChip(count: count),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        Customer? customer;
        for (final item in state.customers) {
          if (item.id == customerId) customer = item;
        }
        if (customer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer')),
            body: const EmptyState(
              message: 'This customer is no longer available.',
            ),
          );
        }
        final selected = customer;
        return Scaffold(
          appBar: AppBar(
            title: Text(selected.name),
            actions: [
              IconButton(
                tooltip: 'Edit',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerFormPage(customer: selected),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () async {
                  final ok = await confirmDelete(
                    context,
                    title: 'Delete customer?',
                    message:
                        'This will also delete this customer\'s sites and notes.',
                  );
                  if (!ok || !context.mounted) return;
                  context.read<CustomerBloc>().add(
                    CustomerDeleted(selected.id),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SiteFormPage(customerId: selected.id),
              ),
            ),
            child: const Icon(Icons.add),
          ),
          body: SiteList(
            customerId: selected.id,
            contactInfo: selected.contactInfo,
          ),
        );
      },
    );
  }
}

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key, this.customer});

  final Customer? customer;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _contact;
  int _seenTick = 0;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name ?? '');
    _contact = TextEditingController(text: widget.customer?.contactInfo ?? '');
    _seenTick = context.read<CustomerBloc>().state.saveTick;
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthBloc>().state.userId;
    final creating = widget.customer == null;
    return BlocListener<CustomerBloc, CustomerState>(
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
                          creating ? 'New customer' : 'Edit customer',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        const FieldLabel('Name'),
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            hintText: 'Company name',
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 14),
                        const FieldLabel('Contact info'),
                        TextField(
                          controller: _contact,
                          decoration: const InputDecoration(
                            hintText: 'Email or phone',
                          ),
                          maxLines: 3,
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
                  : () => context.read<CustomerBloc>().add(
                      CustomerSubmitted(
                        id: widget.customer?.id,
                        userId: userId,
                        name: _name.text,
                        contactInfo: _contact.text,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
