import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter_background/flutter_background.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng currentLatLng = const LatLng(0, 0);
  Position? previousPosition;
  double speed = 0;
  double? altitudeAccuracy;
  double totalDistance = 0;
  BitmapDescriptor? customMarker; // Custom marker for current location
  List<LatLng> polylineCoordinates = []; // Coordinates for polyline
  final Set<Polyline> _polylines = {}; // Set of polylines

  @override
  void initState() {
    super.initState();
    _initializeBackgroundTask();
    _setCustomMarker();
  }

  Future<void> _initializeBackgroundTask() async {
    var backgroundConfig = const FlutterBackgroundAndroidConfig(
      notificationTitle: 'Location Tracking Active',
      notificationText: 'Tracking your location and speed.',
      notificationImportance: AndroidNotificationImportance.high,
    );

    await FlutterBackground.initialize(androidConfig: backgroundConfig);
    await FlutterBackground.enableBackgroundExecution();

    _checkPermissions();
    _startTracking();
  }

  Future<void> _setCustomMarker() async {
    customMarker = await BitmapDescriptor.asset(
        const ImageConfiguration(), 'assets/custom_marker.png',
       //imagePixelRatio: 7,
    height: 45,width: 50,);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _startTracking() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // Geolocator's LocationAccuracy
        distanceFilter: 5, // Minimum distance to trigger updates
      ),
    ).listen((Position currentPosition) {
      setState(() {
        currentLatLng =
            LatLng(currentPosition.latitude, currentPosition.longitude);
        altitudeAccuracy = currentPosition.altitudeAccuracy;
        polylineCoordinates.add(currentLatLng);
        _polylines.add(Polyline(
          polylineId: const PolylineId('tracking_path'),
          points: polylineCoordinates,
          color: Colors.blue,
          width: 4,
        ));
      });

      // Calculate speed and total distance
      if (previousPosition != null) {
        final distance = Geolocator.distanceBetween(
          previousPosition!.latitude,
          previousPosition!.longitude,
          currentPosition.latitude,
          currentPosition.longitude,
        );

        totalDistance += distance; // Add to total distance

        final timeDifference = currentPosition.timestamp
            .difference(previousPosition!.timestamp)
            .inSeconds;
        if (timeDifference > 0) {
          speed = (distance / timeDifference) * 3.6;
        }
      }

      previousPosition = currentPosition;

      // Move camera to current position
      mapController.animateCamera(
        CameraUpdate.newLatLng(currentLatLng),
      );
    });
  }

  Future<void> _checkPermissions() async {
    loc.Location location = loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Speed Tracker")),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: currentLatLng,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            markers: {
              if (customMarker != null)
                Marker(
                  markerId: const MarkerId('current_location'),
                  position: currentLatLng,
                  icon: customMarker!,
                  infoWindow: const InfoWindow(title: "You are here"),
                ),
            },
            //  polylines: _polylines,
          ),
          Positioned(
            bottom: 10,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0XFFDEE4F8),
                    spreadRadius: 4,
                    blurRadius: 7,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Speed: ${speed.toStringAsFixed(2)} km/h"),
                  Text(
                      "Total Distance: ${totalDistance.toStringAsFixed(2)} meters"),
                  Text(
                      "Altitude Accuracy: ${altitudeAccuracy?.toStringAsFixed(2) ?? 'N/A'} meters"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }
}
