// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_simple_ble/flutter_simple_ble.dart';

void main() => runApp(const BleExampleApp());

class BleExampleApp extends StatelessWidget {
  const BleExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Simple BLE',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006E5A)),
      useMaterial3: true,
    ),
    home: const BleInspectorPage(),
  );
}

class BleInspectorPage extends StatefulWidget {
  const BleInspectorPage({super.key});

  @override
  State<BleInspectorPage> createState() => _BleInspectorPageState();
}

enum _ConnectionPhase { disconnected, connecting, connected, disconnecting }

class _BleInspectorPageState extends State<BleInspectorPage> {
  final Map<BleRemoteId, BleScanResult> _scanResults =
      <BleRemoteId, BleScanResult>{};
  final Set<BleRemoteId> _hiddenDeviceIds = <BleRemoteId>{};
  final TextEditingController _valueController = TextEditingController(
    text: '01',
  );

  StreamSubscription<BleAdapterState>? _adapterSubscription;
  StreamSubscription<BleScanResult>? _scanSubscription;
  StreamSubscription<BleConnectionState>? _connectionSubscription;
  BleAdapterState _adapterState = BleAdapterState.unknown;
  BleDevice? _device;
  _ConnectionPhase _connectionPhase = _ConnectionPhase.disconnected;
  BleCharacteristic? _selectedCharacteristic;
  List<BleService> _services = const <BleService>[];
  bool _isSupported = false;
  bool _isScanning = false;
  bool _isWorking = false;
  bool _connectionCancelRequested = false;
  String? _operationLabel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _adapterSubscription = Ble.adapterState.listen((BleAdapterState state) {
      if (mounted) setState(() => _adapterState = state);
    }, onError: _setError);
    _loadSupport();
  }

  @override
  void dispose() {
    unawaited(_adapterSubscription?.cancel());
    unawaited(_scanSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadSupport() async {
    try {
      final bool supported = await Ble.isSupported;
      if (mounted) setState(() => _isSupported = supported);
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> _startScan() async {
    await _stopScan();
    if (!mounted) return;

    setState(() {
      _scanResults.clear();
      _hiddenDeviceIds.clear();
      _error = null;
      _isScanning = true;
    });

    late final StreamSubscription<BleScanResult> subscription;
    subscription = Ble.scan(timeout: const Duration(seconds: 12)).listen(
      (BleScanResult result) {
        if (mounted) {
          setState(() {
            final BleRemoteId remoteId = result.device.remoteId;
            if (_deviceNameOrNull(result.device) == null) {
              _hiddenDeviceIds.add(remoteId);
              return;
            }
            _hiddenDeviceIds.remove(remoteId);
            _scanResults[remoteId] = result;
          });
        }
      },
      onError: _setError,
      onDone: () {
        if (mounted && identical(_scanSubscription, subscription)) {
          setState(() => _isScanning = false);
        }
      },
    );
    _scanSubscription = subscription;
  }

  Future<void> _stopScan() async {
    final StreamSubscription<BleScanResult>? subscription = _scanSubscription;
    _scanSubscription = null;
    await subscription?.cancel();
    if (mounted && _isScanning) setState(() => _isScanning = false);
  }

  Future<void> _connect(BleDevice device) async {
    await _stopScan();
    await _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((
      BleConnectionState state,
    ) {
      if (!mounted) return;
      setState(() {
        if (state == BleConnectionState.connected) {
          _connectionPhase = _ConnectionPhase.connected;
        } else if (_connectionPhase != _ConnectionPhase.connecting) {
          _connectionPhase = _ConnectionPhase.disconnected;
        }
      });
    }, onError: _setError);
    if (!mounted) return;
    setState(() {
      _device = device;
      _connectionPhase = _ConnectionPhase.connecting;
      _connectionCancelRequested = false;
      _services = const <BleService>[];
      _selectedCharacteristic = null;
      _error = null;
    });
    _setWorking(true, 'Connecting to ${_deviceName(device)}');
    try {
      await device.connect(mtu: null);
      if (mounted) {
        setState(() {
          _connectionPhase = _ConnectionPhase.connected;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _connectionPhase = _ConnectionPhase.disconnected);
      }
      if (!_connectionCancelRequested) _setError(error);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _cancelConnection() async {
    final BleDevice? device = _device;
    if (device == null || _connectionPhase != _ConnectionPhase.connecting) {
      return;
    }
    setState(() {
      _connectionCancelRequested = true;
      _connectionPhase = _ConnectionPhase.disconnecting;
      _operationLabel = 'Cancelling connection';
    });
    try {
      await device.disconnect();
      if (mounted) {
        setState(() => _connectionPhase = _ConnectionPhase.disconnected);
      }
    } catch (error) {
      _setError(error);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _disconnect() async {
    final BleDevice? device = _device;
    if (device == null) return;
    if (mounted) {
      setState(() => _connectionPhase = _ConnectionPhase.disconnecting);
    }
    _setWorking(true, 'Disconnecting from ${_deviceName(device)}');
    try {
      await device.disconnect();
      if (mounted) {
        setState(() {
          _connectionPhase = _ConnectionPhase.disconnected;
          _services = const <BleService>[];
          _selectedCharacteristic = null;
        });
      }
    } catch (error) {
      _setError(error);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _discoverServices() async {
    final BleDevice? device = _device;
    if (device == null) return;
    _setWorking(true, 'Discovering services');
    try {
      final List<BleService> services = await device.discoverServices();
      if (mounted) {
        setState(() {
          _services = services;
          _selectedCharacteristic = null;
          _error = null;
        });
      }
    } catch (error) {
      _setError(error);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _requestMtu() async {
    final BleDevice? device = _device;
    if (device == null) return;
    _setWorking(true, 'Requesting MTU');
    try {
      await device.requestMtu(247);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      _setError(error);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _write() async {
    final BleCharacteristic? characteristic = _selectedCharacteristic;
    if (characteristic == null) return;
    _setWorking(true, 'Writing characteristic');
    try {
      final List<int> value = _parseHex(_valueController.text);
      await characteristic.write(
        value,
        withoutResponse:
            !characteristic.properties.write &&
            characteristic.properties.writeWithoutResponse,
      );
      if (mounted) setState(() => _error = null);
    } catch (error) {
      _setError(error);
    } finally {
      _setWorking(false);
    }
  }

  void _setWorking(bool value, [String? label]) {
    if (mounted) {
      setState(() {
        _isWorking = value;
        _operationLabel = value ? label : null;
      });
    }
  }

  void _setError(Object error, [StackTrace? stackTrace]) {
    if (mounted) setState(() => _error = error.toString());
  }

  List<int> _parseHex(String value) {
    final String normalized = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (normalized.isEmpty || normalized.length.isOdd) {
      throw const FormatException('Use complete hex bytes, for example: 01 FF');
    }
    return List<int>.generate(
      normalized.length ~/ 2,
      (int index) =>
          int.parse(normalized.substring(index * 2, index * 2 + 2), radix: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<BleScanResult> results =
        _scanResults.values
            .where(
              (BleScanResult result) =>
                  result.device.remoteId != _device?.remoteId,
            )
            .toList()
          ..sort(
            (BleScanResult first, BleScanResult second) =>
                second.rssi.compareTo(first.rssi),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple BLE inspector'),
        actions: <Widget>[
          IconButton(
            onPressed: _loadSupport,
            tooltip: 'Refresh adapter state',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: <Widget>[
                  Text(
                    'Adapter',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('BLE supported: ${_isSupported ? 'yes' : 'no'}'),
                  Text('State: ${_adapterLabel(_adapterState)}'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton.icon(
              onPressed: _isWorking
                  ? null
                  : _isScanning
                  ? _stopScan
                  : _startScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.radar),
              label: Text(_isScanning ? 'Stop scan' : 'Scan for devices'),
            ),
          ),
          if (_error case final String error)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(error),
                ),
              ),
            ),
          if (_isWorking)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: <Widget>[
                  const LinearProgressIndicator(),
                  if (_operationLabel case final String label) Text(label),
                ],
              ),
            ),
          if (_device case final BleDevice device)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _deviceCard(context, device),
            ),
          if (_services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Services',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ..._services.map(_serviceCard),
          if (_selectedCharacteristic
              case final BleCharacteristic characteristic)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _writeCard(context, characteristic),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  'Named devices',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_hiddenDeviceIds.isNotEmpty)
                  Text(
                    '${_hiddenDeviceIds.length} unnamed hidden',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _isScanning
                    ? 'Looking for named BLE devices...'
                    : _hiddenDeviceIds.isEmpty
                    ? 'Start a scan to find nearby BLE devices.'
                    : 'No named BLE devices found.',
              ),
            ),
          ...results.map(
            (BleScanResult result) => Card(
              child: ListTile(
                title: Text(_deviceName(result.device)),
                subtitle: Text(
                  '${result.device.remoteId}\nRSSI ${result.rssi} dBm',
                ),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed:
                      _isWorking ||
                          _connectionPhase == _ConnectionPhase.connected
                      ? null
                      : () => _connect(result.device),
                  child: const Text('Connect'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(BuildContext context, BleDevice device) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: <Widget>[
          Row(
            spacing: 12,
            children: <Widget>[
              if (_connectionPhase == _ConnectionPhase.connecting ||
                  _connectionPhase == _ConnectionPhase.disconnecting)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _connectionPhase == _ConnectionPhase.connected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                ),
              Expanded(
                child: Text(
                  _deviceName(device),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(_connectionLabel(_connectionPhase)),
            ],
          ),
          Text(device.remoteId.str),
          if (_connectionPhase == _ConnectionPhase.connected)
            Text('MTU: ${device.mtuNow}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed:
                    _isWorking || _connectionPhase != _ConnectionPhase.connected
                    ? null
                    : _discoverServices,
                child: const Text('Discover services'),
              ),
              OutlinedButton(
                onPressed:
                    _isWorking || _connectionPhase != _ConnectionPhase.connected
                    ? null
                    : _requestMtu,
                child: const Text('Request MTU 247'),
              ),
              if (_connectionPhase == _ConnectionPhase.connected)
                TextButton(
                  onPressed: _isWorking ? null : _disconnect,
                  child: const Text('Disconnect'),
                )
              else if (_connectionPhase == _ConnectionPhase.connecting)
                TextButton(
                  onPressed: _cancelConnection,
                  child: const Text('Cancel connection'),
                )
              else if (_connectionPhase == _ConnectionPhase.disconnected)
                TextButton(
                  onPressed: _isWorking ? null : () => _connect(device),
                  child: const Text('Reconnect'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _serviceCard(BleService service) => Card(
    child: ExpansionTile(
      title: Text(service.uuid),
      subtitle: Text(
        service.isPrimary ? 'Primary service' : 'Included service',
      ),
      children: service.characteristics
          .map(
            (BleCharacteristic characteristic) => ListTile(
              title: Text(characteristic.uuid),
              subtitle: Text(_propertiesLabel(characteristic.properties)),
              trailing: _isWritable(characteristic)
                  ? const Icon(Icons.edit)
                  : null,
              onTap: _isWritable(characteristic)
                  ? () =>
                        setState(() => _selectedCharacteristic = characteristic)
                  : null,
            ),
          )
          .toList(growable: false),
    ),
  );

  Widget _writeCard(BuildContext context, BleCharacteristic characteristic) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: <Widget>[
              Text(
                'Write characteristic',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(characteristic.uuid),
              TextField(
                controller: _valueController,
                enabled: !_isWorking,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Hex bytes',
                  hintText: '01 FF A0',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              FilledButton.icon(
                onPressed: _isWorking ? null : _write,
                icon: const Icon(Icons.send),
                label: const Text('Write'),
              ),
            ],
          ),
        ),
      );

  bool _isWritable(BleCharacteristic characteristic) =>
      characteristic.properties.write ||
      characteristic.properties.writeWithoutResponse;

  String _deviceName(BleDevice device) {
    return _deviceNameOrNull(device) ?? 'Unnamed device';
  }

  String? _deviceNameOrNull(BleDevice device) {
    final String advName = device.advName.trim();
    if (advName.isNotEmpty) return advName;
    final String platformName = device.platformName.trim();
    if (platformName.isNotEmpty) return platformName;
    return null;
  }

  String _connectionLabel(_ConnectionPhase phase) => switch (phase) {
    _ConnectionPhase.disconnected => 'Disconnected',
    _ConnectionPhase.connecting => 'Connecting',
    _ConnectionPhase.connected => 'Connected',
    _ConnectionPhase.disconnecting => 'Disconnecting',
  };

  String _propertiesLabel(BleCharacteristicProperties properties) {
    final List<String> labels = <String>[];
    if (properties.read) labels.add('read');
    if (properties.write) labels.add('write');
    if (properties.writeWithoutResponse) labels.add('write without response');
    if (properties.notify) labels.add('notify');
    if (properties.indicate) labels.add('indicate');
    return labels.isEmpty ? 'No supported operations' : labels.join(' | ');
  }

  String _adapterLabel(BleAdapterState state) => switch (state) {
    BleAdapterState.unknown => 'unknown',
    BleAdapterState.unavailable => 'unavailable',
    BleAdapterState.unauthorized => 'permission required',
    BleAdapterState.turningOn => 'turning on',
    BleAdapterState.on => 'on',
    BleAdapterState.turningOff => 'turning off',
    BleAdapterState.off => 'off',
  };
}
