import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'location_result.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation; // Location passed from previous screen

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  final TextEditingController _addressController = TextEditingController();

  LatLng? _userCurrentLocation; // For the non-draggable blue dot
  LatLng? _pickedLocation;      // For the draggable red marker
  
  bool _isFetchingLocation = true; // For initial GPS fetch
  bool _isFetchingAddress = false; // For reverse geocoding

  static const LatLng _defaultCenter = LatLng(24.8607, 67.0011); // Karachi as a fallback center

  @override
  void initState() {
    super.initState();
    // If an initial location is provided, start there.
    if (widget.initialLocation != null) {
      _pickedLocation = widget.initialLocation;
      _isFetchingLocation = false; // We already have a location
      _getAddressFromLatLng(widget.initialLocation!); // Get initial address
    } else {
      // Otherwise, determine current position
      _determinePosition(); 
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled. Please enable them.');
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions were denied.');
          if (mounted) setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied.');
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      final currentLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _userCurrentLocation = currentLatLng; // Blue dot position
          if (_pickedLocation == null) { // If no initial location was set
            _pickedLocation = currentLatLng; // Red marker starts at current
          }
          _isFetchingLocation = false;
        });
      }
      
      // Animate camera to the picked location (or current if no pick yet)
      final GoogleMapController controller = await _controllerCompleter.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _pickedLocation ?? _defaultCenter, zoom: 16.0)));
      
      // Fetch address for the picked location
      if (_pickedLocation != null) {
        _getAddressFromLatLng(_pickedLocation!); 
      }
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (_isFetchingAddress) return;

    if (mounted) {
      setState(() {
        _isFetchingAddress = true;
        _addressController.text = "Fetching address...";
      });
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        // Building address components carefully
        final List<String> addressParts = [];
        if (place.name != null && place.name!.isNotEmpty) addressParts.add(place.name!);
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) addressParts.add(place.thoroughfare!);
        if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty && !addressParts.contains(place.subThoroughfare!)) addressParts.add(place.subThoroughfare!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
        
        final String stateAndPincode = [place.administrativeArea, place.postalCode].where((e) => e != null && e.isNotEmpty).join(' - ');
        if (stateAndPincode.isNotEmpty) addressParts.add(stateAndPincode);

        _addressController.text = addressParts.join(', ');
      } else {
        _addressController.text = "No address found for this location";
      }
    } catch (e) {
      _addressController.text = "Error: Could not fetch address.";
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  void _onMapTapped(LatLng position) {
    if (mounted) {
      setState(() {
        _pickedLocation = position; // Place red marker where tapped
      });
    }
    _getAddressFromLatLng(position); // Fetch address for the new picked location
    // IMPORTANT: No camera animation here to keep map stable for pure marking
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select & Confirm Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_pickedLocation != null) {
                final result = LocationResult(
                  latitude: _pickedLocation!.latitude,
                  longitude: _pickedLocation!.longitude,
                  address: _addressController.text,
                );
                Navigator.of(context).pop(result);
              } else {
                _showSnackBar('Please select a location on the map.');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _controllerCompleter.complete(controller);
                // If initialLocation was provided, animate to it now
                if (widget.initialLocation != null) {
                  controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: widget.initialLocation!, zoom: 16.0)));
                }
              },
              initialCameraPosition: CameraPosition(
                target: widget.initialLocation ?? _defaultCenter, // Use initial or default center
                zoom: 11,
              ),
              onTap: _onMapTapped, // Handle map taps for placing red marker
              // onCameraMove and onCameraIdle are not used for address updates to ensure stability
              markers: {
                // Blue Dot for User's Current Location (non-draggable)
                if (_userCurrentLocation != null)
                  Marker(
                    markerId: const MarkerId('current_location'),
                    position: _userCurrentLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    draggable: false,
                  ),
                // Red Marker for Picked Location (draggable)
                if (_pickedLocation != null)
                  Marker(
                    markerId: const MarkerId('picked_location'),
                    position: _pickedLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    draggable: true,
                    onDragEnd: (LatLng newPosition) {
                      if (mounted) {
                        setState(() {
                          _pickedLocation = newPosition; // Update marker position immediately
                        });
                      }
                      _getAddressFromLatLng(newPosition); // Fetch address for dragged location
                    },
                  ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isFetchingLocation || _isFetchingAddress)
                  const LinearProgressIndicator(),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  readOnly: _isFetchingAddress, // Prevent editing while fetching
                  decoration: const InputDecoration(
                    labelText: 'Selected Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: TextEditingController(text: _pickedLocation?.latitude.toStringAsFixed(6) ?? ''), decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()), readOnly: true)),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: TextEditingController(text: _pickedLocation?.longitude.toStringAsFixed(6) ?? ''), decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()), readOnly: true)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
