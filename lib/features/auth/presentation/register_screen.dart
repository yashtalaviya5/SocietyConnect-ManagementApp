import 'dart:async';

import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/registration_draft.dart';
import '../../community/data/society_repository.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    this.completeExistingAccount = false,
    this.loadRegistrationFlats,
    this.onRegistrationSubmit,
    super.key,
  });

  final bool completeExistingAccount;
  final Future<List<Map<String, dynamic>>> Function(String societyId)?
      loadRegistrationFlats;
  final Future<void> Function(RegistrationDraft draft)? onRegistrationSubmit;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _fullName = TextEditingController();
  final _mobile = TextEditingController();
  final _societyId = TextEditingController();
  final _societyName = TextEditingController();
  final _address = TextEditingController();
  final _contactNumber = TextEditingController();
  Timer? _societyLookupDebounce;
  List<Map<String, dynamic>> _availableFlats = const [];
  String? _selectedFlatId;
  String? _flatLookupError;
  bool _loadingFlats = false;
  int _flatFieldRevision = 0;
  AccountRole _role = AccountRole.resident;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _fullName.dispose();
    _mobile.dispose();
    _societyId.dispose();
    _societyName.dispose();
    _address.dispose();
    _contactNumber.dispose();
    _societyLookupDebounce?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_role == AccountRole.resident) {
      final societyIdError = _societyIdValidator(_societyId.text);
      if (societyIdError != null) {
        _formKey.currentState!.validate();
        return;
      }
      final loaded = await _loadAvailableFlats();
      if (!loaded || _availableFlats.isEmpty) {
        _showMessage(_flatLookupError ??
            'No available flats were found for this Society ID. Contact your society admin.');
        return;
      }
      if (!_availableFlats.any((flat) => flat['id'] == _selectedFlatId)) {
        _showMessage('Select an available flat before continuing.');
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final draft = RegistrationDraft(
      role: _role,
      fullName: _fullName.text.trim(),
      mobile: _mobile.text.trim(),
      societyId: _societyId.text.trim().toUpperCase(),
      societyName: _societyName.text.trim(),
      address: _address.text.trim(),
      contactNumber: _contactNumber.text.trim(),
      flatNumber: _selectedFlat?.value ?? '',
      flatId: _selectedFlatId ?? '',
    );
    try {
      if (widget.onRegistrationSubmit != null) {
        await widget.onRegistrationSubmit!(draft);
      } else if (widget.completeExistingAccount) {
        await authService.completeRegistration(draft);
      } else {
        await authService.createAccount(
          email: _email.text,
          password: _password.text,
          draft: draft,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on AuthFlowException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
            'Registration could not be completed. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onSocietyIdChanged(String value) {
    _societyLookupDebounce?.cancel();
    setState(() {
      _availableFlats = const [];
      _selectedFlatId = null;
      _flatLookupError = null;
      _loadingFlats = false;
      _flatFieldRevision++;
    });
    if (_role != AccountRole.resident || _societyIdValidator(value) != null) {
      return;
    }
    _societyLookupDebounce = Timer(const Duration(milliseconds: 500), () {
      _loadAvailableFlats();
    });
  }

  Future<bool> _loadAvailableFlats() async {
    final societyId = _societyId.text.trim().toUpperCase();
    if (_societyIdValidator(societyId) != null) return false;
    final previousSelection = _selectedFlatId;
    _societyLookupDebounce?.cancel();
    setState(() {
      _loadingFlats = true;
      _flatLookupError = null;
    });
    try {
      final flats = await (widget.loadRegistrationFlats ??
          societyRepository.listRegistrationFlats)(societyId);
      if (!mounted || _societyId.text.trim().toUpperCase() != societyId) {
        return false;
      }
      setState(() {
        _availableFlats = flats
            .where((flat) => flat['flatNumber'] is String)
            .toList(growable: false);
        final selectionRemainsAvailable =
            _availableFlats.any((flat) => flat['id'] == previousSelection);
        if (!selectionRemainsAvailable && previousSelection != null) {
          _selectedFlatId = null;
          _flatFieldRevision++;
        }
        if (_availableFlats.isEmpty) {
          _flatLookupError =
              'No available flats were found for this Society ID. Contact your society admin.';
        }
      });
      return _availableFlats.isNotEmpty;
    } on SocietyDataException catch (error) {
      if (mounted && _societyId.text.trim().toUpperCase() == societyId) {
        setState(() => _flatLookupError = error.message);
      }
      return false;
    } catch (_) {
      if (mounted && _societyId.text.trim().toUpperCase() == societyId) {
        setState(() => _flatLookupError =
            'Could not check this Society ID. Check your connection and try again.');
      }
      return false;
    } finally {
      if (mounted && _societyId.text.trim().toUpperCase() == societyId) {
        setState(() => _loadingFlats = false);
      }
    }
  }

  MapEntry<String, String>? get _selectedFlat {
    final selectedId = _selectedFlatId;
    if (selectedId == null) return null;
    for (final flat in _availableFlats) {
      if (flat['id'] == selectedId && flat['flatNumber'] is String) {
        return MapEntry(selectedId, flat['flatNumber'] as String);
      }
    }
    return null;
  }

  String? _societyIdValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Society ID is required.';
    if (!RegExp(r'^[A-Za-z0-9-]{3,20}$').hasMatch(value.trim())) {
      return 'Use 3–20 letters, numbers, or hyphens.';
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isCompleting = widget.completeExistingAccount;
    return AuthFrame(
      title: isCompleting ? 'Set up your profile' : 'Join SocietyConnect',
      subtitle: isCompleting
          ? 'Your email is verified. Add your society details to finish setup.'
          : 'Create your account. We will verify your email before setting up your society profile.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isCompleting) ...[
              AuthTextField(
                controller: _email,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: validEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _hidePassword,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
                validator: (value) {
                  return validPassword(value);
                },
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _confirmPassword,
                label: 'Confirm password',
                icon: Icons.lock_reset_outlined,
                obscureText: _hidePassword,
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match.' : null,
              ),
              const SizedBox(height: 20),
            ],
            DropdownButtonFormField<AccountRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'I am registering as',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: const [
                DropdownMenuItem(
                    value: AccountRole.resident, child: Text('Resident')),
                DropdownMenuItem(
                    value: AccountRole.admin, child: Text('Society admin')),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() => _role = value!);
                      _onSocietyIdChanged(_societyId.text);
                    },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _fullName,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (value) => requiredField(value, label: 'Full name'),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _mobile,
              label: 'Mobile number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: validMobile,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _societyId,
              label:
                  _role == AccountRole.admin ? 'New Society ID' : 'Society ID',
              icon: Icons.apartment_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: _societyIdValidator,
              onChanged: _onSocietyIdChanged,
            ),
            if (_role == AccountRole.resident) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'available-flat-${_societyId.text.trim().toUpperCase()}-$_flatFieldRevision',
                ),
                initialValue: _selectedFlatId,
                decoration: InputDecoration(
                  labelText: 'Available flat',
                  prefixIcon: const Icon(Icons.door_front_door_outlined),
                  suffixIcon: _loadingFlats
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  errorText: _flatLookupError,
                  helperText: _flatLookupError == null
                      ? (_availableFlats.isEmpty
                          ? 'Enter a valid Society ID to view vacant flats.'
                          : 'Select a vacant flat in this society.')
                      : null,
                  errorMaxLines: 2,
                ),
                items: _availableFlats
                    .map((flat) => DropdownMenuItem<String>(
                          value: flat['id'] as String,
                          child: Text(flat['flatNumber'] as String),
                        ))
                    .toList(growable: false),
                onChanged: _loadingFlats || _availableFlats.isEmpty
                    ? null
                    : (value) => setState(() => _selectedFlatId = value),
                validator: (value) => value == null || value.isEmpty
                    ? 'Select an available flat.'
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Your Society ID and a vacant flat must be provided by your society admin.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              AuthTextField(
                controller: _societyName,
                label: 'Society name',
                icon: Icons.domain_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    requiredField(value, label: 'Society name'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _address,
                label: 'Society address',
                icon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    requiredField(value, label: 'Society address'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _contactNumber,
                label: 'Society contact number',
                icon: Icons.call_outlined,
                keyboardType: TextInputType.phone,
                validator: validMobile,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isCompleting ? 'Finish setup' : 'Create account'),
              ),
            ),
            if (!isCompleting) ...[
              const SizedBox(height: 12),
              Text(
                'Your profile is created only after you verify your email.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
