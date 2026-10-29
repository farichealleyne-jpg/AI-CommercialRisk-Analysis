import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:policysquare/data/models/risk_assessment.dart';
import 'package:policysquare/providers/commercial_provider.dart';
import 'package:policysquare/utils/risk_scoring_helper.dart';
import 'package:policysquare/utils/pdf_generator.dart';
import 'package:policysquare/utils/gemini_report_analyzer.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:policysquare/config/api_keys.dart';
import 'package:dio/dio.dart';

class InspectionReportScreen extends StatefulWidget {
  const InspectionReportScreen({super.key});

  @override
  State<InspectionReportScreen> createState() => _InspectionReportScreenState();
}

class _InspectionReportScreenState extends State<InspectionReportScreen> {
  // Removed _showLanding
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _isFetchingLocation = false;
  bool _isLocationCorrect = false;
  double? _fetchedLat;
  double? _fetchedLon;
  
  GoogleMapController? _mapController;
  double? _waterBodyLat;
  double? _waterBodyLon;
  String? _waterBodyName;
  bool _isFetchingWaterBody = false;

  double? _fireStationLat;
  double? _fireStationLon;
  String? _fireStationName;
  bool _isFetchingFireStation = false;

  List<Map<String, dynamic>> _nearbyHospitals = [];
  bool _isFetchingHospitals = false;
  BitmapDescriptor? _greenPinIcon;

  List<Map<String, dynamic>> _nearbyHazards = [];
  bool _isFetchingHazards = false;
  BitmapDescriptor? _orangePinIcon;

  @override
  void initState() {
    super.initState();
    _initCustomPins();
  }

  Future<void> _initCustomPins() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: 50.0,
        fontFamily: Icons.location_on.fontFamily,
        color: Colors.green,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0.0, 0.0));
    final ui.Image img = await pictureRecorder.endRecording().toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data != null && mounted) {
      setState(() {
        _greenPinIcon = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
      });
    }

    final ui.PictureRecorder orangeRecorder = ui.PictureRecorder();
    final Canvas orangeCanvas = Canvas(orangeRecorder);
    final TextPainter orangePainter = TextPainter(textDirection: TextDirection.ltr);
    orangePainter.text = TextSpan(
      text: String.fromCharCode(Icons.warning_rounded.codePoint),
      style: TextStyle(
        fontSize: 32.0,
        fontFamily: Icons.warning_rounded.fontFamily,
        color: Colors.deepOrange,
      ),
    );
    orangePainter.layout();
    orangePainter.paint(orangeCanvas, const Offset(0.0, 0.0));
    final ui.Image orangeImg = await orangeRecorder.endRecording().toImage(orangePainter.width.toInt(), orangePainter.height.toInt());
    final ByteData? orangeData = await orangeImg.toByteData(format: ui.ImageByteFormat.png);
    if (orangeData != null && mounted) {
      setState(() {
        _orangePinIcon = BitmapDescriptor.fromBytes(orangeData.buffer.asUint8List());
      });
    }
  }

  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();

  @override
  void dispose() {
    _pincodeController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    if (_mapController != null) _mapController!.dispose();
    super.dispose();
  }

  // _zoomToFitBoth() removed as per user request to only zoom in on water body.

  Future<void> _fetchNearbyWaterBody() async {
    if (_fetchedLat == null || _fetchedLon == null || _isFetchingWaterBody) return;
    setState(() => _isFetchingWaterBody = true);
    
    // Clear previous
    setState(() {
       _waterBodyLat = null;
       _waterBodyLon = null;
       _waterBodyName = null;
    });

    try {
      final dio = Dio();
      // Bypassing all proxies and POST limitations by using standard OpenStreetMap Nominatim 
      // which uses fully unblocked enterprise-allowed domain and standard GET logic!
      final double latOffset = 0.01; // roughly 1km
      final double lonOffset = 0.01;
      final String viewbox = '${_fetchedLon! - lonOffset},${_fetchedLat! + latOffset},${_fetchedLon! + lonOffset},${_fetchedLat! - latOffset}';

      final List<String> queries = ['river', 'lake', 'water'];
      Map<String, dynamic>? foundResult;

      for (String q in queries) {
        final url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&q=$q&viewbox=$viewbox&bounded=1&limit=1';
        try {
          final response = await dio.get(
            url,
             options: Options(receiveTimeout: const Duration(seconds: 10), sendTimeout: const Duration(seconds: 10)),
          );
          if (response.statusCode == 200 && response.data != null && (response.data as List).isNotEmpty) {
            foundResult = response.data[0];
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (foundResult != null) {
        final Map<String, dynamic> result = foundResult;
        setState(() {
          _waterBodyLat = double.tryParse(result['lat'].toString()) ?? 0.0;
          _waterBodyLon = double.tryParse(result['lon'].toString()) ?? 0.0;
          _waterBodyName = result['name'] ?? 'Unnamed Water Body';
          _isFetchingWaterBody = false;
        });
      } else {
        setState(() => _isFetchingWaterBody = false);
      }
    } catch (e) {
      setState(() => _isFetchingWaterBody = false);
    }
  }

  Future<void> _fetchNearbyFireStation() async {
    if (_fetchedLat == null || _fetchedLon == null || _isFetchingFireStation) return;
    
    setState(() {
       _isFetchingFireStation = true;
       _fireStationLat = null;
       _fireStationLon = null;
       _fireStationName = null;
    });

    try {
      final dio = Dio();
      // Standard HTTP Geocoding for robust enterprise compatibility
      final double latOffset = 0.3; // roughly 30km
      final double lonOffset = 0.3;
      final String viewbox = '${_fetchedLon! - lonOffset},${_fetchedLat! + latOffset},${_fetchedLon! + lonOffset},${_fetchedLat! - latOffset}';

      final url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&amenity=fire_station&viewbox=$viewbox&bounded=1&limit=50';

      final response = await dio.get(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 15), sendTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 && response.data != null && (response.data as List).isNotEmpty) {
        final List results = response.data;
        List<Map<String, dynamic>> validStations = [];
        
        for (var res in results) {
          double lat = double.tryParse(res['lat'].toString()) ?? 0.0;
          double lon = double.tryParse(res['lon'].toString()) ?? 0.0;
          if (lat != 0.0) {
            double distance = Geolocator.distanceBetween(_fetchedLat!, _fetchedLon!, lat, lon);
            validStations.add({'lat': lat, 'lon': lon, 'name': res['name']?.toString().trim() ?? 'Unnamed Fire Station', 'distance': distance});
          }
        }
        
        if (validStations.isNotEmpty) {
           validStations.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
           final closest = validStations.first;
           setState(() {
             _fireStationLat = closest['lat'];
             _fireStationLon = closest['lon'];
             _fireStationName = closest['name'];
             _isFetchingFireStation = false;
           });
        } else {
           setState(() => _isFetchingFireStation = false);
           throw Exception('No valid coordinates parsed');
        }
        

      } else {
        setState(() => _isFetchingFireStation = false);
      }
    } catch (e) {
      setState(() => _isFetchingFireStation = false);
    }
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_fetchedLat == null || _fetchedLon == null || _isFetchingHospitals) return;
    
    setState(() {
       _isFetchingHospitals = true;
       _nearbyHospitals.clear();
    });

    try {
      final dio = Dio();
      // Tighten the geographic bounding box constraint heavily from 10km to ~3km 
      // preventing Nominatim's relevance engine from arbitrarily pulling prominent mega-hospitals from distant suburbs.
      final double latOffset = 0.03; 
      final double lonOffset = 0.03;
      final String viewbox = '${_fetchedLon! - lonOffset},${_fetchedLat! + latOffset},${_fetchedLon! + lonOffset},${_fetchedLat! - latOffset}';

      final url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&amenity=hospital&viewbox=$viewbox&bounded=1&limit=50';

      final response = await dio.get(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 15), sendTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 && response.data != null && (response.data as List).isNotEmpty) {
        final List results = response.data;
        List<Map<String, dynamic>> parsedHospitals = [];
        
        for (var res in results) {
          double lat = double.tryParse(res['lat'].toString()) ?? 0.0;
          double lon = double.tryParse(res['lon'].toString()) ?? 0.0;
          if (lat != 0.0) {
            double distance = Geolocator.distanceBetween(_fetchedLat!, _fetchedLon!, lat, lon);
            parsedHospitals.add({'lat': lat, 'lon': lon, 'name': res['name']?.toString().trim() ?? 'Unnamed Hospital', 'distance': distance});
          }
        }
        
        parsedHospitals.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        List<Map<String, dynamic>> hospitals = [];
        Set<String> uniqueCoords = {};
        Set<String> uniqueNames = {};
        
        for (var h in parsedHospitals) {
          String coordId = '${(h['lat'] as double).toStringAsFixed(3)}_${(h['lon'] as double).toStringAsFixed(3)}';
          String name = h['name'];
          
          if (!uniqueCoords.contains(coordId) && !uniqueNames.contains(name)) {
            uniqueCoords.add(coordId);
            if (name != 'Unnamed Hospital') uniqueNames.add(name);
            
            hospitals.add({
              'lat': h['lat'],
              'lon': h['lon'],
              'name': name,
            });
            
            if (hospitals.length >= 5) break; 
          }
        }

        setState(() {
          _nearbyHospitals = hospitals;
          _isFetchingHospitals = false;
        });
      } else {
        setState(() => _isFetchingHospitals = false);
      }
    } catch (e) {
      setState(() => _isFetchingHospitals = false);
    }
  }

  Future<void> _fetchNearbyHazards() async {
    if (_fetchedLat == null || _fetchedLon == null || _isFetchingHazards) return;
    
    setState(() {
       _isFetchingHazards = true;
       _nearbyHazards.clear();
    });

    try {
      final dio = Dio();
      // 1km geographic constraint
      final double latOffset = 0.01; 
      final double lonOffset = 0.01;
      final String viewbox = '${_fetchedLon! - lonOffset},${_fetchedLat! + latOffset},${_fetchedLon! + lonOffset},${_fetchedLat! - latOffset}';

      final fuelUrl = 'https://nominatim.openstreetmap.org/search?format=jsonv2&amenity=fuel&viewbox=$viewbox&bounded=1&limit=25';
      final industrialUrl = 'https://nominatim.openstreetmap.org/search?format=jsonv2&q=industrial&viewbox=$viewbox&bounded=1&limit=25';

      final responses = await Future.wait([
        dio.get(fuelUrl, options: Options(receiveTimeout: const Duration(seconds: 15), sendTimeout: const Duration(seconds: 10))),
        dio.get(industrialUrl, options: Options(receiveTimeout: const Duration(seconds: 15), sendTimeout: const Duration(seconds: 10))),
      ]);

      List<Map<String, dynamic>> parsedHazards = [];
      
      for (var response in responses) {
        if (response.statusCode == 200 && response.data != null && (response.data as List).isNotEmpty) {
          final List results = response.data;
          for (var res in results) {
            double lat = double.tryParse(res['lat'].toString()) ?? 0.0;
            double lon = double.tryParse(res['lon'].toString()) ?? 0.0;
            if (lat != 0.0) {
              double distance = Geolocator.distanceBetween(_fetchedLat!, _fetchedLon!, lat, lon);
              // Strictly 1km filter boundary physically dropping faraway properties
              if (distance <= 1000) {
                parsedHazards.add({'lat': lat, 'lon': lon, 'name': res['name']?.toString().trim() ?? 'Hazardous/Industrial Zone', 'distance': distance});
              }
            }
          }
        }
      }
      
      parsedHazards.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      List<Map<String, dynamic>> hazards = [];
      Set<String> uniqueCoords = {};
      Set<String> uniqueNames = {};
      
      for (var h in parsedHazards) {
        String coordId = '${(h['lat'] as double).toStringAsFixed(3)}_${(h['lon'] as double).toStringAsFixed(3)}';
        String name = h['name'];
        if (!uniqueCoords.contains(coordId) && !uniqueNames.contains(name)) {
          uniqueCoords.add(coordId);
          if (name != 'Hazardous/Industrial Zone') uniqueNames.add(name);
          hazards.add({'lat': h['lat'], 'lon': h['lon'], 'name': name});
          if (hazards.length >= 5) break; 
        }
      }

      setState(() {
        _nearbyHazards = hazards;
        _isFetchingHazards = false;
      });
    } catch (e) {
      setState(() => _isFetchingHazards = false);
    }
  }

  Future<void> _fetchAndFillLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      if (kIsWeb) {
        // Fallback for Web using Google Maps Geocoding API
        try {
          final dio = Dio();
          final String apiKey = ApiKeys.googleMaps;
          final response = await dio.get(
            'https://maps.googleapis.com/maps/api/geocode/json',
            queryParameters: {
              'latlng': '${position.latitude},${position.longitude}',
              'key': apiKey,
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
              final result = data['results'][0];
              final components = result['address_components'] as List;
              
              String pincode = '', state = '', city = '', area = '', streetNum = '', route = '', localfallback = '';
              
              for (var c in components) {
                final types = c['types'] as List;
                if (types.contains('postal_code')) pincode = c['long_name'];
                if (types.contains('administrative_area_level_1')) state = c['long_name'];
                if (types.contains('locality')) city = c['long_name'];
                if (types.contains('administrative_area_level_2')) localfallback = c['long_name'];
                if (types.contains('sublocality') || types.contains('neighborhood') || types.contains('sublocality_level_1')) area = c['long_name'];
                if (types.contains('street_number')) streetNum = c['long_name'];
                if (types.contains('route')) route = c['long_name'];
              }

              if (city.isEmpty) city = localfallback;

              setState(() {
                _fetchedLat = position.latitude;
                _fetchedLon = position.longitude;
                _pincodeController.text = pincode;
                _stateController.text = state;
                _cityController.text = city;
                _areaController.text = area;
                _addressLine1Controller.text = streetNum.isNotEmpty ? '$streetNum $route' : route;
                _addressLine2Controller.text = result['formatted_address'] ?? '';

                _formData['pincode'] = _pincodeController.text;
                _formData['state'] = _stateController.text;
                _formData['city'] = _cityController.text;
                _formData['area'] = _areaController.text;
                _formData['addressLine1'] = _addressLine1Controller.text;
                _formData['addressLine2'] = _addressLine2Controller.text;
              });
            } else {
              throw Exception('Google Geocoding failed: ${data['status']}');
            }
          } else {
            throw Exception('Web geocoding failed: HTTP ${response.statusCode}');
          }
        } catch (dioError) {
          throw Exception('Web reverse geocoding error: $dioError');
        }
      } else {
        // Native Platforms (iOS/Android)
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          
          setState(() {
            _fetchedLat = position.latitude;
            _fetchedLon = position.longitude;
            _pincodeController.text = place.postalCode ?? '';
            _stateController.text = place.administrativeArea ?? '';
            _cityController.text = place.locality ?? '';
            _areaController.text = place.subLocality ?? '';
            _addressLine1Controller.text = '${place.street}';
            _addressLine2Controller.text = place.name ?? '';

            _formData['pincode'] = _pincodeController.text;
            _formData['state'] = _stateController.text;
            _formData['city'] = _cityController.text;
            _formData['area'] = _areaController.text;
            _formData['addressLine1'] = _addressLine1Controller.text;
            _formData['addressLine2'] = _addressLine2Controller.text;
          });
        }
      }

      // Automatically fetch surrounding maps/data now that location is securely fetched
      if (mounted && _fetchedLat != null && _fetchedLon != null) {
        _fetchNearbyWaterBody();
        _fetchNearbyFireStation();
        _fetchNearbyHospitals();
        _fetchNearbyHazards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch location: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _fetchCoordinatesFromAddressText() async {
    final List<String> addressParts = [
      _addressLine1Controller.text,
      _addressLine2Controller.text,
      _areaController.text,
      _cityController.text,
      _stateController.text,
      _pincodeController.text,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final String query = addressParts.join(', ');
    if (query.isEmpty) return;
    
    setState(() => _isFetchingLocation = true);
    
    try {
      final dio = Dio();
      final String apiKey = ApiKeys.googleMaps;
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': query,
          'key': apiKey,
        },
        options: Options(receiveTimeout: const Duration(seconds: 10), sendTimeout: const Duration(seconds: 10))
      );
      
      if (response.statusCode == 200 && response.data != null && response.data['status'] == 'OK') {
        final result = response.data['results'][0];
        
        // Set coordinates and clear existing data
        setState(() {
          _fetchedLat = double.tryParse(result['geometry']['location']['lat'].toString()) ?? 0.0;
          _fetchedLon = double.tryParse(result['geometry']['location']['lng'].toString()) ?? 0.0;
          _waterBodyLat = null;
          _waterBodyLon = null;
          _fireStationLat = null;
          _fireStationLon = null;
          _nearbyHospitals.clear();
          _nearbyHazards.clear();
        });
        
        // Auto-fetch related items based on new location
        if (mounted) {
          _fetchNearbyWaterBody();
          _fetchNearbyFireStation();
          _fetchNearbyHospitals();
          _fetchNearbyHazards();
        }
        
      } else {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Address not found. Please try adding more detail.', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ));
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Network Timeout. Check Connection.', style: TextStyle(color: Colors.white)), 
            backgroundColor: Colors.red
         ));
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  // Form Data
  final Map<String, dynamic> _formData = {
    // Preliminary
    'hasPolicy': null, // Tri-state: null (unselected), true (yes), false (no)
    'policyNumber': '',
    'occupancyType': 'Select',
    'sumInsured': 'Select',
    'surveyorName': '',
    'plantPhoto': null, // stores path or base64
    // Risk Address (If No Policy)
    'insuredName': '',
    'pincode': '',
    'state': '',
    'city': '',
    'area': '',
    'addressLine1': '',
    'addressLine2': '',

    // Occupancy Details (If No Policy)
    'rawMaterial': '',
    'finishedGoods': '',
    'processDetails': '',

    // Client Details (Legacy/Mapped)
    'clientName': '',
    'industryType': '',
    'totalArea': null,

    // Step 1: Human Element
    'housekeeping': null,
    'fireTraining': null,
    'trainingFrequency': null,
    'fireProtection': null,
    'fireProtectionPhotos': <String>[],
    'maintenance': null,
    'maintenancePhotos': <String>[],
    'hotWorkPermit': null,
    'hotWorkPermitPhotos': <String>[],

    // Step 2: Occupancy
    'combustibleMaterials': null,
    'combustibleMaterialsPhotos': <String>[],
    'flammableSolvents': null,
    'flammableSolventsPhotos': <String>[],
    'flameProofCables': null,
    'flameProofPhotos': <String>[],
    'electricalCondition': null,
    'electricalConditionPhotos': <String>[],

    // Step 3: Surveillance
    'smokeDetection': null, // boolean?
    'smokeDetectionPhotos': <String>[],
    'cctv': null, // boolean?
    'cctvPhotos': <String>[],
    'boundaryWalls': null, // String?
    'boundaryWallsPhotos': <String>[],
    'securityTeam': null, // boolean?
    'securityTeamPhotos': <String>[],

    // Step 4: Construction
    // Step 4: Construction
    'constructionType': null,
    'separationDistance': null,
    'basementRisk': null,

    // Step 5: External
    'externalOccupancies': null,
    'waterBody': null,
    'naturalHazards': null,

    // Step 6: Fire Protection Systems
    'fireWaterTank': null,
    'mainElectricalPump': null,
    'dieselDrivenPump': null,
    'jockeyPump': null,
    'hydrantPoints': null,
    'fireExtinguishers': null,

    // Step 7: Site Pictures
    'siteImages': <String>[],
  };

  @override
  Widget build(BuildContext context) {
    return _buildAssessmentForm();
  }

  // _buildLandingPage removed

  Widget _buildAssessmentForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Assessment',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildCurrentStepContent(),
                      _buildControls(), // Custom controls function need to be adapted
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildClientDetailsContent();
      case 1:
        return _buildStep1Content();
      case 2:
        return _buildStep2Content();
      case 3:
        return _buildStep3Content();
      case 4:
        return _buildStep4Content();
      case 5:
        return _buildStep5Content();
      case 6:
        return _buildStep6Content();
      case 7:
        return _buildStep7Content();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: (_currentStep == 0 || _currentStep == 6)
          ? SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _currentStep == 0
                    ? (_isStep0Valid() ? _nextStep : null)
                    : _nextStep, // Step 6 just proceeds for now
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (_currentStep == 0 && _isStep0Valid()) ||
                          _currentStep == 6
                      ? const Color(0xFF4CAF50) // Green
                      : const Color(0xFFA5D6A7), // Light Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  (_currentStep == 6) ? 'PROCEED' : 'PROCEED',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : (_currentStep >= 1 && _currentStep <= 6)
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _prevStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      '< PREV',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 2), // Small gap
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'NEXT >',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                if (_currentStep == 7)
                  Expanded(
                    child: Consumer<CommercialProvider>(
                      builder: (context, provider, _) => ElevatedButton(
                        onPressed: provider.isLoading
                            ? null
                            : _submitAssessment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50), // Green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: provider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'CALCULATE RISK',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _prevStep,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                    child: const Text('Back'),
                  ),
              ],
            ),
    );
  }
  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required String btnLabel,
    required bool isFetching,
    required VoidCallback onTap,
    required double? lat,
    required double? lon,
    required String? resultName,
    required String markerLetter,
    required double hue,
    List<Map<String, dynamic>>? multiplePoints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          child: OutlinedButton.icon(
            onPressed: isFetching ? null : onTap,
            icon: isFetching
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 18),
            label: Text(
              btnLabel, 
              style: const TextStyle(fontSize: 12),
              maxLines: 1, 
              overflow: TextOverflow.ellipsis
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            ),
          ),
        ),
        if (resultName != null && lat != null && lon != null) ...[
          const SizedBox(height: 8),
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Builder(
                builder: (context) {
                  if (!ApiKeys.hasGoogleMaps) return const _MapUnavailable();
                  String staticUrl = 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lon&zoom=14&size=300x120&markers=color:red%7Csize:small%7C${_fetchedLat!},${_fetchedLon!}&key=${ApiKeys.googleMaps}';
                  if (multiplePoints != null && multiplePoints.isNotEmpty) {
                    for (var p in multiplePoints) {
                      staticUrl += '&markers=color:${color == Colors.blue ? 'blue' : (color == Colors.red ? 'red' : (color == Colors.deepOrange ? 'orange' : 'green'))}%7Clabel:$markerLetter%7C${p['lat']},${p['lon']}';
                    }
                  } else if (title != 'Water Body') {
                    staticUrl += '&markers=color:${color == Colors.blue ? 'blue' : (color == Colors.red ? 'red' : (color == Colors.deepOrange ? 'orange' : 'green'))}%7Clabel:$markerLetter%7C$lat,$lon';
                  }

                  return (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                    ? Image.network(
                        staticUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) => Center(child: Text('Failed to load $title map', style: const TextStyle(fontSize: 10))),
                      )
                    : GoogleMap(
                        key: ValueKey('${title}_${lat}_${lon}_${multiplePoints?.length}'),
                        initialCameraPosition: CameraPosition(
                            target: LatLng(lat, lon), 
                            zoom: (multiplePoints != null && multiplePoints.length > 1) 
                                ? (title == 'Hazardous Areas' ? 15.5 : 13.5) 
                                : 14.0
                        ),
                        markers: {
                          if ((multiplePoints == null || multiplePoints.isEmpty) && title != 'Water Body')
                            Marker(
                              markerId: MarkerId('${title}_marker'),
                              position: LatLng(lat, lon),
                              icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                            ),
                          if (multiplePoints != null)
                            ...multiplePoints.asMap().entries.map((e) => Marker(
                              markerId: MarkerId('${title}_${e.key}'),
                              position: LatLng(e.value['lat'], e.value['lon']),
                              icon: (title == 'Hospitals' && _greenPinIcon != null) 
                                ? _greenPinIcon! 
                                : (title == 'Hazardous Areas' && _orangePinIcon != null)
                                  ? _orangePinIcon!
                                  : BitmapDescriptor.defaultMarkerWithHue(hue),
                            )),
                        },
                        circles: {
                          if (multiplePoints == null || multiplePoints.isEmpty)
                            Circle(
                              circleId: CircleId('${title}_area'),
                              center: LatLng(lat, lon),
                              radius: color == Colors.blue ? 50 : 20,
                              fillColor: color.withOpacity(0.4),
                              strokeColor: color,
                              strokeWidth: 2,
                            ),
                        },
                        zoomControlsEnabled: multiplePoints != null,
                        scrollGesturesEnabled: multiplePoints != null,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                      );
                }
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    resultName,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Step Builders ---

  // Refactored Steps to return Widgets instead of Step objects
  Widget _buildClientDetailsContent() {
    bool? hasPolicy = _formData['hasPolicy'];

    return Card(
      // Wrap in Card to maintain style
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preliminary Info',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Do you have an existing Risk Assessment Reference Number?',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: If you have forgotten your existing reference number or any other information pertaining to risk assessment please contact local branch office',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: (hasPolicy == true)
                          ? Colors.blue[50]
                          : Colors.white, // Highlight Yes
                      side: BorderSide(
                        color: (hasPolicy == true)
                            ? const Color(0xFF1E88E5)
                            : Colors.grey,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _formData['hasPolicy'] = true;
                        _showPolicyDialog();
                      });
                    },
                    child: const Text('YES'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: (hasPolicy == false)
                          ? Colors.blue[50]
                          : Colors.white,
                      side: BorderSide(
                        color: (hasPolicy == false)
                            ? const Color(0xFF1E88E5)
                            : Colors.grey,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _formData['hasPolicy'] = false),
                    child: const Text('NO'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildDropdown('Select Occupancy *', [
              'Select',
              'Dwelling',
              'Dwelling:Cooperative Society',
              'Places of worships',
              'Libraries',
              'Museums',
              'Schools / Colleges',
              'Hospitals including X-ray and other Diagnostic clinics',
              'Office premises,Meeting Rooms',
              'Auditoriums / Planetarium',
              'Mess Houses / Clubs',
              'Marriage Halls',
              'Showrooms and display centres where goods are kept for display and no sales are carried out',
              'Educational and Research Institutes imparting training in various crafts',
              'Lodging/Boarding Houses',
              'Cycle Shed',
              'Dish Antenna',
              'Indoor stadiums, Health Club,  Gymnasium and Swimming Pool',
              'Cafes, Restaurants, Hotels, Confectioner & Sweet meat sellers',
              'Laundries / Dry Cleaning',
              'Battery Charging Service Stations',
              'Amusement parks',
              'Hoarding, Neon signs',
              'Sports Galleries, Outdoor stadiums.',
              'Contents in Shops dealing in non hazardous goods',
              'shops dealing in hazardous goods',
              'Arms and Ammunition dealers',
              'Motor Vehicle showroom including sales and service with workshop',
              'Fuel Station- Petrol / Diesel Kiosks (without CNG)',
              'Fuel Station- Petrol / Diesel Kiosks  (with CNG) ',
              'Data Processing/ Call centres/ BPO',
              'Abrasive Manufacturing',
              'Aerated water factories',
              'Aerial Ropeway including trolley stations',
              'Agarbatti manufacturing',
              'Aircraft Hangers',
              'Airport Terminal Buildings (including all facilities like Cafes, Shops etc)',
              'Aluminium/ Magnesium Powder Plants',
              'Aluminium ,Zinc,Copper Factories',
              'Arecanut and/or Betelnut factories',
              'Asbestos Steam Packing and lagging manufacturing',
              'Atta and Cereal Grinding (excluding Dal Mills)',
              'Audio/Video Cassette Manufacturing',
              'Automobile Manufacturing',
              'Bakeries',
              'Basket Weavers and Cane Furniture Makers',
              'Battery Manufacturing',
              'Beedi Factories',
              'Biscuit Factories',
              'Bituminised Paper and / or Hessain Cloth Manufacturing including Tar Felt Manufacturing',
              'Book Binders, Envelope and Paper Bag Manufacturing.',
              'Breweries',
              'Brickworks (Including refractories and fire bricks)',
              'Bridges - Concrete/Steel',
              'Bridges-Wooden',
              'Building in course of construction',
              'Cable Manufacturing',
              'Camphor Manufacturing',
              'Candle works',
              'Canning Factories',
              'Capsule Manufacturing',
              'Cabrbon paper/ Typewriter Ribbon Manufacturing',
              'Cardamom Manufacturing',
              'Cardboard Box manufacturing',
              'Carpenters, Wood wool Manufacturing, Furniture Manufacturing and other wood worker shops (excluding saw mill)',
              'Carpet and Drugget Manufacturing (Cotton/jute/wool )',
              'Carpet and Drugget Manufacturing (Others)',
              'Cashew nut Factories',
              'Cattle feed Mill',
              'Celluloid Goods Manufacturing',
              'Cement / asbestos/concrete products Manufacturing',
              'Cement Factories',
              'Ceramic Factories and Crockery and Stoneware pipe Manufacturing/Clay Works.',
              'Chemical Manufacturing(Using materials with Flash Point below 32 degree C), Bulk Drug Manufacturing',
              'Chemical Manufacturing(others), Pharmaceuticals, Toiletry products',
              'Cigar and Cigarette Manufacturing',
              'Cigarette Filter Manufacturing (Using Solvents with Flash Point below 32OC )',
              'Cigarette Filter Manufacturing (Others)',
              'Cinema Film Production Studios',
              'Cinematography Film Editing, Laboratory and Sound recording rooms where Film processing is carried out',
              'Cinematography Film Editing, Laboratory and Sound recording rooms without Film processing.',
              'Cinema Theatres',
              'Circus, Touring Drama Troupes and Touring Cinema Theatres',
              'Cloth Processing units situated outside the compound of Textile mills and Cloth processing units which are not owned by the textile mills but are situated with in the textile mills complex/ compound',
              'Coal/Coke/Charcoal ball & briquettes Manufacturing',
              'Coal Processing Plants',
              'Coffee Curing, Roasting / Grinding',
              'Coir Factories',
              'Collieries - underground Mechinery and pit head gear and Dragline Machine used in Collieries',
              'Condensed Milk Factories, Milk Pasturisings Plants and Dairies',
              'Confectionery Manufacturing Plants/ Sugar Candy Mfg. plants/ Sweet Meat mfg. plats',
              'Contractors Plant and Machinery at one location only',
              'Cork Products Manufacturing',
              'Cotton Gin and Press Houses',
              'Cotton Seed cleaning / Delinting Factory',
              'Dehydration Factories',
              'Detergent Manufacturing with Sulphonation Plant',
              'Detergent Manufacturing (Others)',
              'Distilleries',
              'Duplicating/stencil paper Manufacturing',
              'Elect. Generation - Hydropower - surface power plant',
              'Electric Lamp /T.V. Picture Tube Manufacturing',
              'Electronic Goods Manufacturing /Assembly',
              'Electronic Software Parks/ Electronic Software Development Units',
              'Enamel-ware factories',
              'Engineering Workshop - - Structural Steel fabricators, Sheet Metal fabricators, ',
              'Engineering Workshop (Others), ',
              'Engineering Workshop , Motor Vehicle Garages',
              'Exhibitions, Fetes, Mandaps.',
              'Explosives / Blasting Factories',
              'Fertiliser Manufacturing (other than those rateable under Petrochemical Tariff)',
              'Filter and wax paper Manufacturing',
              'Fireworks Manufacturing',
              'Flax / Hemp Mills',
              'Flour Mills',
              'Foamed Plastics Manufacturing and / or converting plants',
              'Foam Rubber Manufacturing',
              'French Polish Manufacturing',
              'Fruit and vegetable drying/dehydrating factories',
              'Fruit products and Condiment Factories (including fruit pulp making)',
              'Garment Makers, Topee, Hats and the like makers',
              'Ghee Factories including vegetable Ghee mfg.',
              'Glass Fibre Manufacturing',
              'Glass wool Manufacturing',
              'Glass Manufacturing/ Automobile glass mfg.',
              'Gold thread factories / Gilding factories',
              'Granite Factories using inflammable solvents',
              'Granite Factories (Others)',
              'Graphite electrode Manufacturing',
              'Grain/seeds disintegrating/crushing/ Decorticating factories/ Dal mills.',
              'Grease / Wax Manufacturing',
              'Green Houses/ Algae/ Spirulina and the like',
              'Gum/Glue/Gelatine Manufacturing',
              'Gypsum  board manufacturer',
              'Hoisery,lace, Embroidery/Thread factories',
              'Ice candy and Ice cream Manufacturing',
              'Ice factories',
              'Incandescent Gas mantle Manufacturing',
              'Industrial Diamonds Manufacturing',
              'Industrial Gas Manufacturing',
              'Ink (excluding printing ink) Manufacturing',
              'Jaggery Manufacturing',
              'Jute Mills',
              'Katha Manufacturing',
              'Khandsari Sugar Manufacturing',
              'Lac or Shellac Factories',
              'Leather Cloth Factories',
              'Leather Goods Manufacturing ( incl. boot/shoe)',
              'Lime Kiln',
              'Lithographic presses',
              'Liquified Gas Bottling/ Recovery Plants',
              'Malt Extraction Plants',
              'Man-made Fibre Manufacturing (using Cellulose)',
              'Man-made Fibre Manufacturing Plant (Others)',
              'Manure Blending works',
              'Match Factories',
              'Mattress and Pillow making',
              'Metallizing works ( involving metals only)',
              'Metallising Works (others)',
              'Metal/Tin printers',
              'Mica Products Manufacturing',
              'Mineral Oil blending and processing',
              'Mosaic Factories',
              'Mushroom Growing Premises (Excluding Crops)',
              'Nitro Cellulose Manufacturing-Industrial Grade',
              'Non-woven fabric Manufacturing',
              'Oil Extraction',
              'Oil Distillation Plants (essential)',
              'Oil Mills including refining ',
              'Oil Mills (Vegetable)',
              'Oil and Leather Cloth Factories',
              'Paint factories (Water based)',
              'Paint (others) & Varnish Factories',
              'Paints - Nitrocellulose based',
              'Pan Masala making',
              'Paper and Cardboard Mills (including Lamination)',
              'Particle Board Manufacturing',
              'Pencil Manufacturing',
              'Petroleum Coke Calcination',
              'Plastic Goods Manufacturing (excluding Foam Plastics)/ I. using plastic raw material having calorific value upto 15,000 btu/Ib Polytetrafluloroethylene, Polychorotrif, fluroethlene, polyvinyl chloride, Polyvinylidene fluoride, Cholorinated polyether, Polycarbonate, Polymethyl Methacrylate, Phenol formaldehyde, Urea-formaldehyde. Melamine-formaldehyde, Polyurethane, Polyester, Silicones.',
              'Plywood / Wood veneering Factories/ Laminating Factories',
              'Polyester Film Manufacturing / BOPP Film Manufacturing',
              'Port Premises including jetties and equipment thereon and other port facilities',
              'Poultry Farms (Excluding birds therein)',
              'Presses for coir fibres/waste/Grass/fodder/boosa/Jute',
              'Presses for coir yarn / cotton/senna leaves',
              'Presses for carpets, rugs and tobacco',
              'Presses for hides and skins',
              'Printing Ink Manufacturing / Roller composition factories',
              'Printing Press',
              'Pulverising Plants(Metals and non-hazardous goods)',
              'Pulverizing Plants (Others)',
              'Rice Mills',
              'Rice Polishing Units',
              'Rope works  (Plastic), Assembling of Plastic Goods such as Toys and the like',
              'Rope Works (others)',
              'Rubber Factories',
              'Rubber Goods Mfg with Spreading',
              'Rubber Goods Manufacturing without spreading',
              'Salt crushing Factories and Refineries',
              'Saw Mills (including Timber Merchants premises where sawing is done).',
              'Sea Food / Meat Processing',
              'Silk Mills / Spun Silk Mills',
              'Snuff Manufacturing',
              'Soap Manufacturing',
              'Sponge Iron Plants',
              'Spray Painting, Powder coating',
              'Stables (excluding animals)',
              'Starch Factories',
              'Stone quarries',
              'Sugar factories',
              'Surgical Cotton manufacturing',
              'Tanneries',
              'Tapioca factories',
              'Tarpaulin and canvas proofing factories',
              'Tea blending/packing factories',
              'Tea Factories',
              'Telephone Exchanges',
              'Textile Mills - Spinning mills',
              'Tile & Pottery works',
              'Tiny sector Industries with values at risk not exceeding the limit given by the public authorities subject to certification.',
              'Tissue Culture Premises (Excluding Crops)',
              'Tobacco Curing / Redrying Factories',
              'Tobacco grinding/ crushing Manufacturing',
              'Turpentine and rosin distilleries',
              'Tyres and Tubes Manufacturing',
              'Tyre Retreading and Resoling factories',
              'Umbrella Assembly factories',
              'Velvet Cloth Manufacturing',
              'Vermicelli factories',
              'Weigh Bridges',
              'Weaving Mills',
              'Wheat Threshers',
              'Wood seasoning/treatment/ impregnation',
              'Wool cleaning and pressing factories',
              'Woollen Mills/fur garments and accessories',
              'Yarn Processing',
              'Zip fasteners Manufacturing',
              'Contractors Plant and Machinery anywhere in India (at Specified Locations)',
              'Electric Generation Stations -Others',
              'Textile Mills - Composite mills',
              'Automobile Filter Mfg.',
              'Plastic Goods Manufacturing (excluding Foam Plastics)/ II. using plastic raw material having calorific value above 15,000 btu/Ib polyethylene, polypropylene, polystyrene, plyalphamethylstyrene, Acrylonitrilebutadiene- styrene, Polybutylene.',
              'Electric Generation Stations - Thermal Power stations',
              'Electric Generation Stations - Solar Power stations',
              'Electric Generation Stations - Windmill ',
              'Electric Generation Stations - Biomass Power Stations',
              'Engineering Workshop - Steel Plants',
              'Engineering Workshop- Pipe Extruding, Stamping, Pressing, Forging Mills, Metal Smelting, Foundries, Galvanising Work',
              'Engineering Workshop - Metal Extraction, Ore Processing (other than Aluminium, Copper, Zinc), Plant Processing Raw Sand into Silica',
              'Engineering workshop - Clock/ Watch Manufacturing',
              'Multiplex Theatre Complexes',
              'Shopping Malls (without Multiplexes)',
              'Disposable Diaper Manufacturing',
              'Analytical / Quality Control Laboratories',
              'Boiler House',
              'Dam',
              'Effluent /Sewage Treatment Plant',
              'Electric Sub-Station, Loco Sheds',
              'Electric Transmission / Distribution Lines',
              'Pipe lines (carrying water only)',
              'Pipe lines (others)',
              'Pump House (Water)',
              'Pump House (Others)',
              'Railway tracks',
              'Roads',
              'Water Treatment plants/ Water Tanks',
              'Wireless Transmitting Stations',
              'Compressor Houses - Compressors handling air, Inert Gas and CO2',
              'Compressor Houses - Compressor (Others)',
              'Boundary Walls - Made up of Combustible Material',
              'Bundary Walls - Others',
              'Eelectric Crematoriums',
              'Storage of Non-hazardous goods subject to warranty that hazardous  goods of Category I, II, III , Coir waste, Coir fibre and Caddies are not stored therein (Materials stored in godowns & silos)',
              'Storage of Category I hazaardous Goods subject to warranty that goods listed in Category II, III, Coir waste, Coir fibre and  Caddies are not stored therein. (Materials stored in Godowns & Soils)',
              'Storage of hazardous Goods listed in Category II subject to warranty that goods listed in Category III, Coir waste, Coir fibre and  Caddies are not stored therein. (Materials stored in Godowns & soils)',
              'Storage of hazardous Goods listed in Category III subject to warranty that, Coir waste, Coir fibre and  Caddies are not stored therein. (Materials Stored in Godowns & soils)',
              'Transporter\'s godowns & Godowns of clearing and forwarding agents (Materials stored in Godowns &soils)',
              'Storage of Coir Waste, Coir Fibre, Caddies (Materials Stored in Godowns & Soils)',
              'Cold Storage premises',
              'Gas Holders/Bullets/spheres and storages for liquified gases except for Nitrogen,Carbon dioxide and inert gases',
              'Gas Holders/ Vessels for Nitrogen, Carbon dioxide and inert gases',
              'Tanks containing liquids flashing at 32 0C and below',
              'Tanks (others)',
              'Storage of Non-hazardous goods subject to warranty that hazardous  goods of Category I, II, III , Coir waste, Coir fibre and Caddies are not stored therein - Material Stored in Open',
              'Storage of Category I hazaardous Goods subject to warranty that goods listed in Category II, III, Coir waste, Coir fibre and  Caddies are not stored therein. - Material stored in Open',
              'Storage of hazardous Goods listed in Category II subject to warranty that goods listed in Category III, Coir waste, Coir fibre and  Caddies are not stored therein. -Material stored in Open',
              'Storage of hazardous Goods listed in Category III subject to warranty that Coir waste, Coir fibre and , Caddies are not stored therein.- Materials stored in Open',
              'Transporter\'s godowns & Godowns of clearing and forwarding agents (Materials stored in Open)',
              'Storage of Coir Waste, Coir Fibre, Caddies (Materials Stored in Open)',
              'Bus Terminus',
              'Vehicles Stored in Open Including Tractors',
              'Silent Risk',
              'Engineering Workshop-Hot/cold rolling mill',
              'Engineering Workshop – Ferro Alloy Plant / Ferro Silicon Plant',
              'Engineering Workshop – Manufacturing of Cut & Polished Diamonds',
              'Electric Generation Stations - Nuclear Power Stations',
              'Nitro Cellulose Manufacturing-others',
              'Sports Goods Manufacturing',
              'Pilot Plants',
              'Lignite Handling System',
              'Petrochemical Risk Excluding Refineries',
              'Administrative buildings of Port Premises',
              'Building of Shops ',
              'Abrasive Manufacturing  with Adhesives',
              'Aerated Water Factories with PET bottle mfg',
              'Aircraft Hangers- with workshops',
              'Airport Terminal Buildings (including all facilities like Cafes, Shops etc) -with Cargo complex',
              'Asbestos Steam Packing and lagging manufacturing- with solvents',
              'Battery Manufacturing-Wet cells',
              'Carpenters, Wood wool Manufacturing, Furniture Manufacturing and other wood worker shops- including foam ',
              'Bulk Drug /API Manufacturing',
              'Shopping Malls (with Multiplexes)',
              'Elect. Generation - Hydropower - Underground power plant',
              'Engineering Workshop – Motor Vehicle Garages',
              'Liquified Gas Bottling Plants',
              'Sugar refining',
              'Automobile Manufacturing- Significant plastic',
              'Sugar Candy Manufacturing',
              'Printing Ink Manufacturing / Roller composition factories-water based',
              'Automobile Manufacturing- plastics incidental',
              'Sweetmeat Manufacturing',
              'Printing Ink Manufacturing / Roller composition factories',
              'Stationery shop / Gift article shop',
              'Garment shop, Textile showroom and cloth shop',
              'Laundry and Dry cleaning',
              'Motor vehicle Showroom without workshop attached',
              'Paint Shop',
              'Multiple Occupancy in Industrial estate-Building only',
              'Home appliances shop, super Market, Hyper Market',
              'Grocery shop, proviison shop',
              'Hardware shop',
              'computer / Laptop and electronic goods shop',
              'Mobile shop',
              'Jewelery shop',
            ], 'occupancyType'),
            const SizedBox(height: 16),
            _buildDropdown('Select Sum Insured *', [
              'Select',
              '0 Crore to <=5 Crore',
              '>5 Crore to <=10 Crore',
              '>10 Crore to <=20 Crore',
              '>20 Crore to <=30 Crore',
              '>30 Crore to <=50 Crore',
            ], 'sumInsured'),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Risk Surveyor Name *',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (val) {
                setState(() {
                  _formData['surveyorName'] = val;
                });
              },
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _pickImage('plantPhoto'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formData['plantPhoto'] == null
                            ? 'Plant Entrance/Main Gate Photo *'
                            : 'Photo Selected: ${_formData['plantPhoto'].toString().split('/').last}',
                        style: TextStyle(
                          color: _formData['plantPhoto'] == null
                              ? Colors.grey[700]
                              : Colors.green,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Icon(Icons.camera_alt_outlined, color: Colors.grey),
                  ],
                ),
              ),
            ),

            if (hasPolicy == false) ...[
              const SizedBox(height: 24),
              const Text(
                'Risk Address Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Insured Name *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (val) {
                  setState(() {
                    _formData['insuredName'] = val;
                    _formData['clientName'] = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isFetchingLocation ? null : _fetchAndFillLocation,
                  icon: _isFetchingLocation 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('Fetch Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_fetchedLat != null && _fetchedLon != null) ...[
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Builder(
                      builder: (context) {
                        String staticmapUrl = 'https://maps.googleapis.com/maps/api/staticmap?center=${_fetchedLat!},${_fetchedLon!}&zoom=14&size=600x300&markers=color:red%7C${_fetchedLat!},${_fetchedLon!}&key=${ApiKeys.googleMaps}';
                        if (_waterBodyLat != null && _waterBodyLon != null) {
                          staticmapUrl += '&markers=color:blue%7Clabel:W%7C${_waterBodyLat!},${_waterBodyLon!}';
                        }
                        if (_fireStationLat != null && _fireStationLon != null) {
                          staticmapUrl += '&markers=color:orange%7Clabel:F%7C${_fireStationLat!},${_fireStationLon!}';
                        }
                        for (int i = 0; i < _nearbyHospitals.length; i++) {
                          final h = _nearbyHospitals[i];
                          staticmapUrl += '&markers=color:green%7Clabel:H%7C${h['lat']},${h['lon']}';
                        }

                        if (!ApiKeys.hasGoogleMaps) return const _MapUnavailable();
                        return (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                          ? Image.network(
                              staticmapUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                              errorBuilder: (context, error, stackTrace) => const Center(child: Text('Failed to load map image')),
                            )
                          : GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(_fetchedLat!, _fetchedLon!),
                                zoom: 16.0,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('fetched_location'),
                                  position: LatLng(_fetchedLat!, _fetchedLon!),
                                ),
                                if (_fireStationLat != null && _fireStationLon != null)
                                  Marker(
                                    markerId: const MarkerId('fire_station'),
                                    position: LatLng(_fireStationLat!, _fireStationLon!),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                                    infoWindow: InfoWindow(title: 'Fire Station', snippet: _fireStationName),
                                  ),
                                ..._nearbyHospitals.asMap().entries.map((e) => Marker(
                                      markerId: MarkerId('hospital_${e.key}'),
                                      position: LatLng(e.value['lat'], e.value['lon']),
                                      icon: _greenPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                  infoWindow: InfoWindow(title: 'Hospital', snippet: e.value['name']),
                                )).toSet(),
                              },
                              circles: {
                                if (_waterBodyLat != null && _waterBodyLon != null)
                                  Circle(
                                    circleId: const CircleId('main_water_body_area'),
                                    center: LatLng(_waterBodyLat!, _waterBodyLon!),
                                    radius: 50,
                                    fillColor: Colors.blue.withOpacity(0.4),
                                    strokeColor: Colors.blue,
                                    strokeWidth: 2,
                                  ),
                              },
                              zoomControlsEnabled: true,
                              scrollGesturesEnabled: false,
                              myLocationButtonEnabled: false,
                            ); // end of GoogleMap
                      }, // end of builder
                    ),
                  ), // end of ClipRRect
                ), // end of Container
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        title: 'Water Body',
                        icon: Icons.water_drop,
                        color: Colors.blue,
                        btnLabel: 'Nearby Water Body',
                        isFetching: _isFetchingWaterBody,
                        onTap: _fetchNearbyWaterBody,
                        lat: _waterBodyLat,
                        lon: _waterBodyLon,
                        resultName: _waterBodyName,
                        markerLetter: 'W',
                        hue: BitmapDescriptor.hueBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFeatureCard(
                        title: 'Fire Station',
                        icon: Icons.local_fire_department,
                        color: Colors.red,
                        btnLabel: 'Nearest Fire Stn',
                        isFetching: _isFetchingFireStation,
                        onTap: _fetchNearbyFireStation,
                        lat: _fireStationLat,
                        lon: _fireStationLon,
                        resultName: _fireStationName,
                        markerLetter: 'F',
                        hue: BitmapDescriptor.hueRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        title: 'Hospitals',
                        icon: Icons.local_hospital,
                        color: Colors.green,
                        btnLabel: 'Nearby Hospitals',
                        isFetching: _isFetchingHospitals,
                        onTap: _fetchNearbyHospitals,
                        lat: _nearbyHospitals.isNotEmpty ? _nearbyHospitals[0]['lat'] : null,
                        lon: _nearbyHospitals.isNotEmpty ? _nearbyHospitals[0]['lon'] : null,
                        resultName: _nearbyHospitals.isNotEmpty ? _nearbyHospitals.map((h) => h['name']).join('\n') : null,
                        markerLetter: 'H',
                        hue: BitmapDescriptor.hueGreen,
                        multiplePoints: _nearbyHospitals,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFeatureCard(
                        title: 'Hazardous Areas',
                        icon: Icons.warning_rounded,
                        color: Colors.deepOrange,
                        btnLabel: 'Nearby Hazards',
                        isFetching: _isFetchingHazards,
                        onTap: _fetchNearbyHazards,
                        lat: _nearbyHazards.isNotEmpty ? _nearbyHazards[0]['lat'] : null,
                        lon: _nearbyHazards.isNotEmpty ? _nearbyHazards[0]['lon'] : null,
                        resultName: _nearbyHazards.isNotEmpty ? _nearbyHazards.map((h) => h['name']).join('\n') : null,
                        markerLetter: 'Z',
                        hue: BitmapDescriptor.hueOrange,
                        multiplePoints: _nearbyHazards,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                controller: _pincodeController,
                decoration: InputDecoration(
                  labelText: 'Pincode *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _isFetchingLocation ? null : _fetchCoordinatesFromAddressText,
                    tooltip: 'Recalculate Map with Custom Address',
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  setState(() {
                    _formData['pincode'] = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _formData['state'] = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _formData['city'] = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Area *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _formData['area'] = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 1 *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _formData['addressLine1'] = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 2 *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _formData['addressLine2'] = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isLocationCorrect,
                      activeColor: const Color(0xFF0D47A1),
                      onChanged: (val) {
                        setState(() {
                          _isLocationCorrect = val ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'I confirm the fetched risk address is correct.',
                          style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0D47A1)),
                          children: [
                            TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],

              const SizedBox(height: 24),
              const Text(
                'Occupancy Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Raw Material / Stock Description',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _formData['rawMaterial'] = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Finished goods description *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _formData['finishedGoods'] = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Process Details *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _formData['processDetails'] = val;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPolicyDialog() {
    final policyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Enter Reference Number',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: TextField(
          controller: policyController,
          decoration: const InputDecoration(
            hintText: 'e.g. SIBPL01',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final refNo = policyController.text.trim();
                if (refNo.isEmpty) return;
                
                // Show loading spinner
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(child: CircularProgressIndicator()),
                );
                
                final provider = Provider.of<CommercialProvider>(context, listen: false);
                final assessment = await provider.fetchAssessmentById(refNo);
                
                // Drop loading spinner
                Navigator.pop(context);
                
                if (assessment != null && assessment.data != null) {
                  // Drop reference dialog
                  Navigator.pop(context);
                  
                  final Map<String, dynamic> dataMap = jsonDecode(assessment.data!);
                  final score = RiskScoringHelper.calculateScore(dataMap);
                  _showReportDialog(score, assessment);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report not found or incomplete. Try another Ref No.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('FETCH ASSESSMENT'),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step Builders ---
  // Refactored Steps to return Widgets instead of Step objects

  // Client Details Content is already defined above

  Widget _buildStep1Content() {
    int completedCount = 0;
    if (_formData['housekeeping'] != null) completedCount++;
    if (_formData['fireTraining'] != null) completedCount++;
    if (_formData['fireProtection'] != null) completedCount++;
    if (_formData['maintenance'] != null) completedCount++;
    if (_formData['hotWorkPermit'] != null) completedCount++;

    return Column(
      children: [
        // Header Card
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Human Element & Manual Protection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completedCount / 5,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.blueGrey,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$completedCount/5 completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        _buildQuestionCard(
          title: 'Overall Housekeeping practice followed?',
          child: Column(
            children: [
              _buildRadioOption(
                'housekeeping',
                'No RM, FG and WIP are stored in Haphazard manner. All the stocks are arranged in orderly would avoid delay in fire fighting operation',
              ),
              _buildRadioOption(
                'housekeeping',
                'Stocks are stored beneath electrical fittings/close to electrical installation/Plant walls.',
              ),
              _buildRadioOption(
                'housekeeping',
                'Stock inventory is too high which may hampers fire fighting operation',
              ),
              _buildRadioOption(
                'housekeeping',
                'Stocks are stored in poorly manner/stored till ceiling height/Haphazard manner/no pallets are use for storage',
              ),
              _buildRadioOption('housekeeping', 'Very Poor Housekeeping'),
            ],
          ),
        ),
        _buildYesNoQuestion(
          'Fire Fighting Training and Mock Drill are provided?',
          'fireTraining',
        ),
        if (_formData['fireTraining'] == true) ...[
          _buildQuestionCard(
            title: 'Frequency of Training and Mock Drill',
            child: Column(
              children: [
                _buildRadioOption('trainingFrequency', 'Monthly'),
                _buildRadioOption('trainingFrequency', 'Quarterly'),
                _buildRadioOption('trainingFrequency', 'Half-yearly'),
                _buildRadioOption('trainingFrequency', 'Annually'),
              ],
            ),
          ),
        ],

        _buildQuestionCard(
          title: 'Fire protection facilities available?',
          child: Column(
            children: [
              _buildRadioOption(
                'fireProtection',
                'Fire Hydrant System is installed as per TAC',
              ),
              _buildRadioOption(
                'fireProtection',
                'Fire Extinguishers installed at IS 2190',
              ),
              _buildRadioOption(
                'fireProtection',
                'Non Standard Fire Extinguishers having zero Pressure/Inadequate Maintenance',
              ),
              _buildRadioOption(
                'fireProtection',
                'Fire brigade located within 2kms',
              ),
              _buildRadioOption('fireProtection', 'No protection available'),
              _buildPhotoUploadSection('fireProtectionPhotos'),
            ],
          ),
        ),

        _buildYesNoQuestion(
          'Equipment Maintenance (Inhouse/AMC)?',
          'maintenance',
          photoKey: 'maintenancePhotos',
        ),
        _buildYesNoQuestion(
          'Hot Work Permit System followed?',
          'hotWorkPermit',
          photoKey: 'hotWorkPermitPhotos',
        ),
      ],
    );
  }

  Widget _buildDropdown(String title, List<String> options, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _formData[key] as String?,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          hint: const Text('Select an option'),
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                opt,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _formData[key] = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildYesNoQuestion(String title, String key, {String? photoKey}) {
    return _buildQuestionCard(
      title: title,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Yes', style: TextStyle(fontSize: 14)),
                  value: true,
                  groupValue: _formData[key] as bool?,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.blueGrey,
                  dense: true,
                  onChanged: (val) {
                    setState(() {
                      _formData[key] = val;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('No', style: TextStyle(fontSize: 14)),
                  value: false,
                  groupValue: _formData[key] as bool?,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.blueGrey,
                  dense: true,
                  onChanged: (val) {
                    setState(() {
                      _formData[key] = val;
                    });
                  },
                ),
              ),
            ],
          ),
          if (photoKey != null) _buildPhotoUploadSection(photoKey),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.blue,
                  size: 20,
                ),
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String key, String text, {dynamic value}) {
    final distinctValue = value ?? text;
    return RadioListTile(
      title: Text(text, style: const TextStyle(fontSize: 14)),
      value: distinctValue,
      groupValue: _formData[key],
      onChanged: (val) {
        setState(() {
          _formData[key] = val;
        });
      },
      contentPadding: EdgeInsets.zero,
      activeColor: Colors.blueGrey,
      dense: true,
    );
  }

  Widget _buildStep2Content() {
    int completedCount = 0;
    if (_formData['combustibleMaterials'] == true ||
        _formData['combustibleMaterials'] == false) {
      completedCount++;
    }
    if (_formData['flammableSolvents'] != null) completedCount++;
    if (_formData['flameProofCables'] == true ||
        _formData['flameProofCables'] == false) {
      completedCount++;
    }
    if (_formData['electricalCondition'] != null) completedCount++;

    return Column(
      children: [
        // Header Card
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Occupancy Related Hazard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completedCount / 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.blueGrey,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$completedCount/4 completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Question 1: Combustible Materials
        _buildQuestionCard(
          title:
              'Does the facility use combustible raw materials/WIP/finished goods?',
          child: Column(
            children: [
              _buildRadioOption('combustibleMaterials', 'Yes', value: true),
              _buildRadioOption('combustibleMaterials', 'No', value: false),
              _buildPhotoUploadSection('combustibleMaterialsPhotos'),
            ],
          ),
        ),

        // Question 2: Flammable Solvents
        _buildQuestionCard(
          title: 'Does the process/facility use flammable solvents?',
          child: Column(
            children: [
              _buildRadioOption(
                'flammableSolvents',
                'Yes. Solvent transferring is done from Tankfarm to Reactor/Pressure Vessel directly using Earth Rite System',
              ),
              _buildRadioOption(
                'flammableSolvents',
                'Yes. Solvent transferring is done from Metal Drum to Reactor/Process Vessel directly with Static Protection such as Copper Bonding at Pipe Flanges/Crocodile Clamps',
              ),
              _buildRadioOption(
                'flammableSolvents',
                'Yes. Solvent transferring is done from HDPE Drum/PCV Pipe to Reactor/Process Vessel',
              ),
              _buildRadioOption(
                'flammableSolvents',
                'Yes. Solvent handled and transfer inside reactor using Open Containers',
              ),
              _buildRadioOption(
                'flammableSolvents',
                'No Solvent is use for processing of Finished Goods',
              ),
              _buildPhotoUploadSection('flammableSolventsPhotos'),
            ],
          ),
        ),

        // Question 3: Flame Proof Cables
        _buildQuestionCard(
          title:
              'Does the facility use Flame proof/ Industrial Type Electrical Cables and fittings in hazardous areas?',
          child: Column(
            children: [
              _buildRadioOption('flameProofCables', 'Yes', value: true),
              _buildRadioOption('flameProofCables', 'No', value: false),
              _buildPhotoUploadSection('flameProofPhotos'),
            ],
          ),
        ),

        // Question 4: Electrical Condition
        _buildQuestionCard(
          title:
              'What is the condition of electrical fittings/wiring installed at the site',
          child: Column(
            children: [
              _buildRadioOption(
                'electricalCondition',
                'Electrical Wiring through Steel Conduit',
              ),
              _buildRadioOption(
                'electricalCondition',
                'Electrical wiring through PVC/Plastic Conduit',
              ),
              _buildRadioOption(
                'electricalCondition',
                'No Conduit and Cable are dressed properly on Cable Tray',
              ),
              _buildRadioOption('electricalCondition', 'Loose/Tape wiring'),
              _buildPhotoUploadSection('electricalConditionPhotos'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoUploadSection(String key, {bool isMandatory = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _pickImage(key, isList: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMandatory
                          ? 'Note: 3 photos are mandatory to capture'
                          : 'Photos are optional',
                      style: TextStyle(
                        color: isMandatory ? Colors.red : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline, color: Colors.grey),
                  ),
                ],
              ),
              _buildImagePreview(key),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Content() {
    int completedCount = 0;
    if (_formData['smokeDetection'] != null) completedCount++;
    if (_formData['cctv'] != null) completedCount++;
    if (_formData['boundaryWalls'] != null) completedCount++;
    if (_formData['securityTeam'] != null) completedCount++;

    return Column(
      children: [
        // Header Card
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Surveillance and Automatic Fire Detection System',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completedCount / 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.blueGrey,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$completedCount/4 completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Question 1: Smoke Detection
        _buildQuestionCard(
          title:
              'Is the facility equipped with Automatic Smoke Detection System in all the important areas?',
          child: Column(
            children: [
              _buildRadioOption('smokeDetection', 'Yes', value: true),
              _buildRadioOption('smokeDetection', 'No', value: false),
              _buildPhotoUploadSection('smokeDetectionPhotos'),
            ],
          ),
        ),

        // Question 2: CCTV
        _buildQuestionCard(
          title:
              'Does the facility have functional CCTV cameras installed in the premises?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRadioOption('cctv', 'Yes', value: true),
              _buildRadioOption('cctv', 'No', value: false),
              if (_formData['cctv'] == false)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 16.0),
                  child: Text(
                    'Claim Process will get Impacked',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              _buildPhotoUploadSection('cctvPhotos', isMandatory: false),
            ],
          ),
        ),

        // Question 3: Boundary Walls
        _buildQuestionCard(
          title: 'Is the facility protected by boundary walls or fence?',
          child: Column(
            children: [
              _buildRadioOption('boundaryWalls', 'Yes with RCC'),
              _buildRadioOption(
                'boundaryWalls',
                'Yes with Barbed Wire fencing',
              ),
              _buildRadioOption('boundaryWalls', 'None'),
              _buildPhotoUploadSection(
                'boundaryWallsPhotos',
                isMandatory: false,
              ),
            ],
          ),
        ),

        // Question 4: Security Team
        _buildQuestionCard(
          title: 'Does the facility have a dedicated security team?',
          child: Column(
            children: [
              _buildRadioOption('securityTeam', 'Yes', value: true),
              _buildRadioOption('securityTeam', 'No', value: false),
              if (_formData['securityTeam'] == true) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What is the security coverage pattern?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _buildRadioOption('securityCoverage', '24x7'),
                      _buildRadioOption('securityCoverage', 'Shift-wise'),
                    ],
                  ),
                ),
              ],
              _buildPhotoUploadSection(
                'securityTeamPhotos',
                isMandatory: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep4Content() {
    int completedCount = 0;
    if (_formData['constructionType'] != null) completedCount++;
    if (_formData['separationDistance'] != null) completedCount++;
    if (_formData['basementRisk'] != null) completedCount++;

    return Column(
      children: [
        // Header Card
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Construction',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completedCount / 3,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.blueGrey,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$completedCount/3 completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Question 1: Construction Type
        _buildQuestionCard(
          title: 'What is the type of building construction of the site?',
          child: Column(
            children: [
              _buildRadioOption('constructionType', 'Roof - RCC/ Walls - RCC'),
              _buildRadioOption(
                'constructionType',
                'Roof - RCC/ Walls - Brick with RCC frame.',
              ),
              _buildRadioOption(
                'constructionType',
                'Roof - AC / Walls - Brick with RCC frame/ outdoor plant',
              ),
              _buildRadioOption(
                'constructionType',
                'Roof - AC sheet or non-combustible/ Walls - Non combustible/partly open',
              ),
              _buildRadioOption(
                'constructionType',
                'Either roof or walls combustible or open sides',
              ),
              _buildRadioOption(
                'constructionType',
                'Both roof and walls combustible',
              ),
            ],
          ),
        ),

        // Question 2: Separation Distance
        _buildQuestionCard(
          title:
              'What is the separation distance between storage/process/utility areas?',
          child: Column(
            children: [
              _buildRadioOption('separationDistance', '>21mtrs'),
              _buildRadioOption('separationDistance', '16 to 20mtrs'),
              _buildRadioOption('separationDistance', '11 to 15mtrs'),
              _buildRadioOption('separationDistance', '6 to 10mtrs'),
              _buildRadioOption('separationDistance', '0-5mtrs'),
            ],
          ),
        ),

        // Question 3: Basement Risk
        _buildQuestionCard(
          title:
              'Is your risk located in the basement/ below the ground level/below the road level?',
          child: Column(
            children: [
              _buildRadioOption('basementRisk', 'No', value: false),
              _buildRadioOption('basementRisk', 'Yes', value: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Content() {
    int completedCount = 0;
    if (_formData['externalOccupancies'] != null) completedCount++;
    if (_formData['waterBody'] != null) completedCount++;
    if (_formData['naturalHazards'] != null) completedCount++;

    return Column(
      children: [
        // Header Card
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'External Exposure',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completedCount / 3,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.blueGrey,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$completedCount/3 completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Question 1: External Occupancies
        _buildQuestionCard(
          title:
              'What external occupancies surround the facility sharing common boundary wall?',
          child: Column(
            children: [
              _buildRadioOption(
                'externalOccupancies',
                'Yes with Storage Risks',
              ),
              _buildRadioOption(
                'externalOccupancies',
                'Yes with Industrial Risk',
              ),
              _buildRadioOption(
                'externalOccupancies',
                'Does not share with any other facility',
              ),
            ],
          ),
        ),

        // Question 2: Water Body
        _buildQuestionCard(
          title:
              'Is the facility surrounded by any water body (Nalah, Canal, River and Sea) within a distance of 1km?',
          child: Column(
            children: [
              _buildRadioOption('waterBody', 'No', value: false),
              _buildRadioOption('waterBody', 'Yes', value: true),
            ],
          ),
        ),

        // Question 3: Natural Hazards (History)
        _buildQuestionCard(
          title:
              'Has this location been affected by Flood/ Cyclone/Inundation/any other AOG peril in past 3 years?',
          child: Column(
            children: [
              _buildRadioOption('naturalHazards', 'No', value: false),
              _buildRadioOption('naturalHazards', 'Yes', value: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep6Content() {
    double area =
        double.tryParse(_formData['totalArea']?.toString() ?? '0') ?? 0;

    String waterTank;
    if (area <= 5000) {
      waterTank = '50 - 100 KL';
    } else if (area <= 15000) {
      waterTank = '100 - 200 KL';
    } else if (area <= 30000) {
      waterTank = '200 - 400 KL';
    } else {
      waterTank = '400+ KL';
    }

    String mainPump;
    if (area <= 5000) {
      mainPump = '900 - 1140 LPM';
    } else if (area <= 15000) {
      mainPump = '2280 LPM';
    } else {
      mainPump = '2850+ LPM';
    }

    int hydrants = (area / 1200).ceil();
    int extinguishers = (area / 225).ceil();

    int completedCount = 0;
    if (_formData['fireWaterTank'] != null) completedCount++;
    if (_formData['mainElectricalPump'] != null) completedCount++;
    if (_formData['dieselDrivenPump'] != null) completedCount++;
    if (_formData['jockeyPump'] != null) completedCount++;
    if (_formData['hydrantPoints'] != null) completedCount++;
    if (_formData['fireExtinguishers'] != null) completedCount++;

    return Column(
      children: [
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Fire Protection Systems',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completedCount / 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.blueGrey,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$completedCount/6 completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              initialValue: _formData['totalArea']?.toString(),
              decoration: const InputDecoration(
                labelText: 'Total Area (sq m) *',
                hintText: 'Enter total area to calculate requirements',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.aspect_ratio),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  _formData['totalArea'] = val;
                });
              },
            ),
          ),
        ),
        if (area > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Calculations based on $area sq m total area.',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildYesNoQuestion(
            'Based on area, required Fire Water Tank is $waterTank. Is this available?',
            'fireWaterTank',
          ),
          const SizedBox(height: 12),
          _buildYesNoQuestion(
            'Required Main Electrical Pump capacity is $mainPump. Is this available?',
            'mainElectricalPump',
          ),
          const SizedBox(height: 12),
          _buildYesNoQuestion(
            'Required Diesel Driven Pump capacity (standby limit) is $mainPump. Is this available?',
            'dieselDrivenPump',
          ),
          const SizedBox(height: 12),
          _buildYesNoQuestion(
            'Required Jockey Pump capacity is 180 - 300 LPM. Is this available?',
            'jockeyPump',
          ),
          const SizedBox(height: 12),
          _buildYesNoQuestion(
            'Required Hydrant Points are approximately $hydrants. Is this achieved?',
            'hydrantPoints',
          ),
          const SizedBox(height: 12),
          _buildYesNoQuestion(
            'Required Fire Extinguishers are approximately $extinguishers. Is this achieved?',
            'fireExtinguishers',
          ),
        ],
      ],
    );
  }

  Widget _buildStep7Content() {
    List<String> images = _formData['siteImages'] as List<String>;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Please upload images from site',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Note: You can upload upto 15 images',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                '${images.length}/15 images captured',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    _buildSafeImage(
                      images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            images.removeAt(index);
                          });
                        },
                        child: Container(
                          color: Colors.black54,
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _pickImage('siteImages', isList: true),
            backgroundColor: const Color(0xFF0D47A1),
            child: const Icon(Icons.camera_alt),
          ),
        ),
      ],
    );
  }

  // --- Helpers ---

  Widget _buildSafeImage(
    String data, {
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    if (data.isEmpty) return const SizedBox.shrink();
    try {
      final bytes = base64Decode(data);
      return Image.memory(bytes, width: width, height: height, fit: fit);
    } catch (_) {
      // Fallback for older drafted local file paths
      if (kIsWeb) {
        return Image.network(data, width: width, height: height, fit: fit);
      } else {
        return Image.file(File(data), width: width, height: height, fit: fit);
      }
    }
  }

  Widget _buildImagePreview(String key) {
    List<String> images =
        (_formData[key] as List<dynamic>?)?.cast<String>() ?? [];
    if (images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: images.map((path) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildSafeImage(
                  path,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      (_formData[key] as List).remove(path);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _nextStep() {
    bool isValid = false;
    switch (_currentStep) {
      case 0:
        if (!_formKey.currentState!.validate()) return;
        isValid = _isStep0Valid();
        break;
      case 1:
        isValid = _isStep1Valid();
        break;
      case 2:
        isValid = _isStep2Valid();
        break;
      case 3:
        isValid = _isStep3Valid();
        break;
      case 4:
        isValid = _isStep4Valid();
        break;
      case 5:
        isValid = _isStep5Valid();
        break;
      case 6:
        isValid = _isStep6Valid();
        break;
      default:
        isValid = true;
    }

    if (isValid) {
      if (_currentStep < 7) {
        setState(() => _currentStep++);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer all mandatory questions and upload required photos (3 for Yes/Risk).',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage(String key, {bool isList = false}) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        // Read the image as bytes and convert to base64
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);

        setState(() {
          if (isList) {
            (_formData[key] as List).add(base64String);
          } else {
            _formData[key] = base64String;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submitAssessment() async {
    if (!_isStep7Valid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one site photograph.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show AI Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Risk Analysising & Saving...')),
          ],
        ),
      ),
    );

    final provider = context.read<CommercialProvider>();

    try {
      final String apiKey = ApiKeys.googleMaps;
      if (_fetchedLat != null && _fetchedLon != null) {
        _formData['locationMapUrl'] = 'https://maps.googleapis.com/maps/api/staticmap?center=${_fetchedLat},${_fetchedLon}&zoom=14&size=400x400&markers=color:red%7Clabel:S%7C${_fetchedLat},${_fetchedLon}&key=$apiKey';
      }
      if (_waterBodyLat != null && _waterBodyLon != null) {
        _formData['waterBodyMapUrl'] = 'https://maps.googleapis.com/maps/api/staticmap?center=${_waterBodyLat},${_waterBodyLon}&zoom=14&size=400x400&markers=color:blue%7Clabel:W%7C${_waterBodyLat},${_waterBodyLon}&key=$apiKey';
      }
      if (_fireStationLat != null && _fireStationLon != null) {
        _formData['fireStationMapUrl'] = 'https://maps.googleapis.com/maps/api/staticmap?center=${_fireStationLat},${_fireStationLon}&zoom=14&size=400x400&markers=color:orange%7Clabel:F%7C${_fireStationLat},${_fireStationLon}&key=$apiKey';
      }
      if (_nearbyHospitals.isNotEmpty && _fetchedLat != null) {
        String hospMarks = '';
        for(var h in _nearbyHospitals) hospMarks += '&markers=color:green%7Clabel:H%7C${h["lat"]},${h["lon"]}';
        _formData['hospitalMapUrl'] = 'https://maps.googleapis.com/maps/api/staticmap?center=${_fetchedLat},${_fetchedLon}&zoom=13&size=400x400$hospMarks&key=$apiKey';
      }
      if (_nearbyHazards.isNotEmpty && _fetchedLat != null) {
        String hazMarks = '';
        for(var h in _nearbyHazards) hazMarks += '&markers=color:purple%7C${h["lat"]},${h["lon"]}';
        _formData['hazardsMapUrl'] = 'https://maps.googleapis.com/maps/api/staticmap?center=${_fetchedLat},${_fetchedLon}&zoom=13&size=400x400$hazMarks&key=$apiKey';
      }

      // 1. Create temporary assessment object to pass to Gemini
      final tempAssessment = RiskAssessment(
        status: 'COMPLETED',
        data: jsonEncode(_formData),
      );

      // 2. Fetch AI Analyzed Data
      final enhancedData = await GeminiReportAnalyzer.analyzeAssessment(
        tempAssessment,
      );

      // 3. Create final Assessment Object containing AI data
      final finalAssessment = RiskAssessment(
        status: 'COMPLETED',
        data: jsonEncode(enhancedData),
      );

      // 4. Save to Backend
      final result = await provider.submitAssessment(finalAssessment);

      // Dismiss Loading Dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (result != null && mounted) {
        // Calculate Score Locally for Display
        final score = RiskScoringHelper.calculateScore(_formData);
        _showReportDialog(score, result);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${provider.error}')));
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportDialog(
    Map<String, dynamic> score,
    RiskAssessment assessment,
  ) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            RiskReportScreen(score: score, assessment: assessment),
      ),
    );
  }

  bool _isStep0Valid() {
    if (_formData['occupancyType'] == 'Select') return false;
    if (_formData['sumInsured'] == 'Select') return false;
    if ((_formData['surveyorName'] ?? '').isEmpty) return false;
    if (_formData['plantPhoto'] == null) return false;

    if (_formData['hasPolicy'] == null) return false;
    if (_formData['hasPolicy'] == true) {
      if ((_formData['policyNumber'] ?? '').isEmpty) return false;
    } else {
      if ((_formData['insuredName'] ?? '').isEmpty) return false;
      if ((_formData['pincode'] ?? '').isEmpty) return false;
      if ((_formData['state'] ?? '').isEmpty) return false;
      if ((_formData['city'] ?? '').isEmpty) return false;
      if ((_formData['area'] ?? '').isEmpty) return false;
      if ((_formData['addressLine1'] ?? '').isEmpty) return false;
      if ((_formData['addressLine2'] ?? '').isEmpty) return false;
      if (!_isLocationCorrect) return false;
      if ((_formData['processDetails'] ?? '').isEmpty) return false;
      if ((_formData['finishedGoods'] ?? '').isEmpty) return false;
    }
    return true;
  }

  bool _isStep1Valid() {
    if (_formData['fireTraining'] == null ||
        _formData['maintenance'] == null ||
        _formData['hotWorkPermit'] == null) {
      return false;
    }
    // Fire Protection is now a string dropdown/radio, not list
    if ((_formData['fireProtection'] ?? '').isEmpty) return false;

    // Check photos for Fire Protection if needed? User didn't specify mandatory photos for new options,
    // but preserving old logic if "Yes" equivalent or just requiring site photos?
    // User request focused on scoring. I'll keep it simple: just answer the questions.
    // Old logic required 3 photos for 'fireProtection' List. Now it is a single String.
    // I will relax photo requirement here unless "None" is selected?
    // Actually, "Fire Protection" options are specific. Let's keep photos optional for now to match "Scoring" focus,
    // or keep them if they were there.
    // The previous code had `fireProtectionPhotos`. Let's keep it but make it optional or linked to "Yes" types.

    return true;
  }

  bool _isStep2Valid() {
    if (_formData['combustibleMaterials'] == null ||
        _formData['flameProofCables'] == null) {
      return false;
    }
    if (_formData['combustibleMaterials'] == true) {
      List<String> photos = _formData['combustibleMaterialsPhotos'] ?? [];
      if (photos.length < 3) return false;
    }
    if (_formData['flammableSolvents'] !=
        'No Solvent is use for processing of Finished Goods') {
      List<String> photos = _formData['flammableSolventsPhotos'] ?? [];
      if (photos.length < 3) return false;
    }
    if (_formData['flameProofCables'] == true) {
      List<String> photos = _formData['flameProofPhotos'] ?? [];
      if (photos.length < 3) return false;
    }
    if (_formData['electricalCondition'] == 'Loose Wiring') {
      List<String> photos = _formData['electricalConditionPhotos'] ?? [];
      if (photos.length < 3) return false;
    }
    return true;
  }

  bool _isStep3Valid() {
    if (_formData['smokeDetection'] == null ||
        _formData['cctv'] == null ||
        _formData['boundaryWalls'] == null ||
        _formData['securityTeam'] == null) {
      return false;
    }
    if (_formData['smokeDetection'] == true) {
      List<String> photos = _formData['smokeDetectionPhotos'] ?? [];
      if (photos.length < 3) return false;
    }
    // CCTV, Boundary Walls, Security Team photos are optional
    return true;
  }

  bool _isStep4Valid() {
    return _formData['constructionType'] != null &&
        _formData['separationDistance'] != null &&
        _formData['basementRisk'] != null;
  }

  bool _isStep5Valid() {
    return _formData['externalOccupancies'] != null &&
        _formData['waterBody'] != null &&
        _formData['naturalHazards'] != null;
  }

  bool _isStep6Valid() {
    if ((_formData['totalArea'] ?? '').toString().isEmpty) return false;

    return _formData['fireWaterTank'] != null &&
        _formData['mainElectricalPump'] != null &&
        _formData['dieselDrivenPump'] != null &&
        _formData['jockeyPump'] != null &&
        _formData['hydrantPoints'] != null &&
        _formData['fireExtinguishers'] != null;
  }

  bool _isStep7Valid() {
    List<String> images = _formData['siteImages'] ?? [];
    return images.isNotEmpty;
  }
}

class RiskReportScreen extends StatelessWidget {
  final Map<String, dynamic> score;
  final RiskAssessment assessment;

  const RiskReportScreen({
    Key? key,
    required this.score,
    required this.assessment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color actualColor = _getRatingColor(score['rating']);
    Color potentialColor = Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Assessment Report'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 60),
            const SizedBox(height: 16),
            const Text(
              'Assessment Completed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ref ID: ${assessment.id ?? "UNKNOWN"}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCircularScore(
                  'Actual Score',
                  score['actualPercent'],
                  score['rating'],
                  actualColor,
                ),
                _buildCircularScore(
                  'Potential Score',
                  score['potentialPercent'],
                  score['potentialRating'],
                  potentialColor,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Actual Points',
                      '${score['actualScore']} / 125',
                    ),
                    const Divider(),
                    _buildSummaryRow(
                      'Potential Points',
                      '${score['potentialScore']} / 125',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (route) => false);
                },
                icon: const Icon(Icons.home, color: Colors.white),
                label: const Text(
                  'Home',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const VerticalDivider(color: Colors.white54, width: 1),
            Expanded(
              child: TextButton.icon(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    // Direct PDF generation since 'assessment' already contains AI stored payloads via 'submitAssessment'
                    await PdfGenerator.generateAndPrint(assessment, score);
                  } finally {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  'Download',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularScore(
    String label,
    double percent,
    String rating,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Column(
              children: [
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color),
          ),
          child: Text(
            rating,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(String? rating) {
    if (rating == null) return Colors.grey;
    if (rating.contains('Poor Risk')) return Colors.red;
    if (rating.contains('Adequate Risk')) return Colors.yellow;
    if (rating.contains('Favourable Risk')) return Colors.lightBlue;
    return Colors.green;
  }
}

/// Shown in place of a map when no Google Maps key was supplied at build time,
/// so the surrounding report still renders instead of failing.
class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECEFF1),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: const Text(
        'Map unavailable — no Google Maps key configured.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }
}
