import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/flask_models.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';

enum InvoiceLoadingStatus {
  /// Initial state
  initial,

  /// Loading invoices
  loading,

  /// Invoices loaded successfully
  loaded,

  /// Error loading invoices
  error,
}

class FlaskInvoicesProvider with ChangeNotifier {
  // Services
  final FlaskApiService _apiService = FlaskApiService();

  // Internal state
  InvoiceLoadingStatus _status = InvoiceLoadingStatus.initial;
  List<FlaskInvoiceModel> _invoices = [];
  FlaskInvoiceModel? _selectedInvoice;
  String? _errorMessage;

  // Getters
  InvoiceLoadingStatus get status => _status;
  List<FlaskInvoiceModel> get invoices => _invoices;
  FlaskInvoiceModel? get selectedInvoice => _selectedInvoice;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == InvoiceLoadingStatus.loading;

  // Load all user invoices
  Future<void> loadInvoices() async {
    _status = InvoiceLoadingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _invoices = await _apiService.getInvoices();
      _status = InvoiceLoadingStatus.loaded;
    } catch (e) {
      _status = InvoiceLoadingStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Load a specific invoice
  Future<void> loadInvoice(int invoiceId) async {
    _status = InvoiceLoadingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if invoice is already in the list with items
      _selectedInvoice = _invoices.firstWhere(
        (invoice) => invoice.id == invoiceId && invoice.items != null,
        orElse: () => throw Exception('Invoice not found or items not loaded'),
      );

      // If not found with items, fetch from API
      if (_selectedInvoice == null || _selectedInvoice!.items == null) {
        final fetchedInvoice = await _apiService.getInvoice(invoiceId);
        if (fetchedInvoice == null) {
          throw Exception('Invoice not found');
        }
        _selectedInvoice = fetchedInvoice;

        // Update the invoice in the list if it exists
        final index = _invoices.indexWhere((invoice) => invoice.id == invoiceId);
        if (index >= 0) {
          _invoices[index] = _selectedInvoice!;
        }
      }

      _status = InvoiceLoadingStatus.loaded;
    } catch (e) {
      _status = InvoiceLoadingStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Get pending invoices
  List<FlaskInvoiceModel> get pendingInvoices {
    return _invoices.where((invoice) => invoice.status == 'pending').toList();
  }

  // Get completed invoices
  List<FlaskInvoiceModel> get completedInvoices {
    return _invoices.where((invoice) => invoice.status == 'completed').toList();
  }

  // Get cancelled invoices
  List<FlaskInvoiceModel> get cancelledInvoices {
    return _invoices.where((invoice) => invoice.status == 'cancelled').toList();
  }

  // Clear selected invoice
  void clearSelectedInvoice() {
    _selectedInvoice = null;
    notifyListeners();
  }
} 