import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/service_model.dart';

class ServiceFormDialog extends StatefulWidget {
  final ServiceModel? service;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;

  const ServiceFormDialog({
    super.key,
    this.service,
    required this.onSave,
  });

  @override
  State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late String _priceType;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _descriptionController = TextEditingController(text: widget.service?.description ?? '');
    _priceType = widget.service?.priceType ?? 'per_kg';
    _unitController = TextEditingController(
      text: widget.service?.unit ?? (_priceType == 'per_kg' ? 'kg' : 'pcs'),
    );
    _priceController = TextEditingController(
      text: widget.service != null
          ? (widget.service!.price % 1 == 0
              ? widget.service!.price.toInt().toString()
              : widget.service!.price.toString())
          : '',
    );
    _durationController = TextEditingController(
      text: widget.service?.estimatedDurationHours?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final duration = int.tryParse(_durationController.text.trim());

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      'price_type': _priceType,
      'unit': _unitController.text.trim().toLowerCase(),
      'price': price.toStringAsFixed(2),
      'estimated_duration_hours': duration,
      'is_active': widget.service?.isActive ?? true,
    };

    setState(() => _isSubmitting = true);
    final success = await widget.onSave(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.successGreen.withAlpha(25),
                        child: Icon(
                          isEditing ? Icons.edit_outlined : Icons.dry_cleaning_outlined,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing ? 'Ubah Layanan Laundry' : 'Tambah Layanan Baru',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Layanan *',
                      hintText: 'Misal: Cuci Komplit, Bed Cover, Setrika Kilat',
                      prefixIcon: Icon(Icons.label_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama layanan wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Price Type Selector
                  DropdownButtonFormField<String>(
                    initialValue: _priceType,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Penetapan Harga *',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'per_kg',
                        child: Text('Kiloan (per kg)'),
                      ),
                      DropdownMenuItem(
                        value: 'per_item',
                        child: Text('Satuan (per pcs/item)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _priceType = val;
                          if (_unitController.text.isEmpty ||
                              _unitController.text == 'kg' ||
                              _unitController.text == 'pcs') {
                            _unitController.text = val == 'per_kg' ? 'kg' : 'pcs';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Unit & Price in Row
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(
                            labelText: 'Satuan *',
                            hintText: 'kg / pcs',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Satuan wajib';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Harga (Rp) *',
                            hintText: 'Misal: 8000',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Harga wajib diisi';
                            }
                            final numVal = double.tryParse(val.trim());
                            if (numVal == null || numVal <= 0) {
                              return 'Harga harus > 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Duration Field
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Estimasi Durasi (Jam)',
                      hintText: 'Misal: 24, 48 (Opsional)',
                      suffixText: 'Jam',
                      prefixIcon: Icon(Icons.timer_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi / Keterangan Layanan',
                      hintText: 'Misal: Cuci bersih, wangi, setrika rapi...',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEditing ? 'Simpan Perubahan' : 'Tambah Layanan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
