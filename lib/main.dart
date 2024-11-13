import 'dart:async'; // Import for using Timer
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart'; // Import the flutter_svg package

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air France Airplanes Map',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        textTheme: TextTheme(
          titleLarge: TextStyle(
            fontSize: 22.0, // Adjust according to Material 3 guidelines
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: Scaffold(
        backgroundColor: Color(0xFF002157), // Set the background color here
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start, // Align items to the start
            children: [
              // Leading Menu Button
              IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  // Handle menu action
                },
              ),
              // Add the logo next to the menu button
              Container(
                margin: EdgeInsets.only(left: 8.0, right: 8.0), // Add margin for spacing
                child: SvgPicture.asset(
                  'assets/Air_France_Logo.svg', // Path to your SVG logo
                  fit: BoxFit.contain, // Adjust the image fitting
                  height: 20, // Set the height of the logo
                ),
              ),
              // Title text
              Spacer(),
              Text(
                'Air France Airplanes Map',
                style: TextStyle(fontSize: 20), // Adjust title text size if needed
              ),
              Spacer(),
            ],
          ),
          elevation: 0,
          toolbarHeight: 80,
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                // Handle search action
              },
            ),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                // Handle settings action
              },
            ),
          ],
        ),
        body: AirplanesMap(),
      ),
    );
  }
}

class AirplanesMap extends StatefulWidget {
  @override
  _AirplanesMapState createState() => _AirplanesMapState();
}

class _AirplanesMapState extends State<AirplanesMap> {
  List<Marker> airplaneMarkers = [];
  double zoomLevel = 2.0;
  Timer? timer;
  Map<String, bool> hoverStates = {}; // Store hover states

  // Replace with your OpenSky username and password
  final String username = 'AzizPistol';
  final String password = 'Ce@Pt37sgNdSiWu  ';

  @override
  void initState() {
    super.initState();
    fetchAirplanes();
    timer = Timer.periodic(Duration(minutes: 2), (Timer t) => fetchAirplanes());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  double _calculateIconSize(double zoomLevel, double? altitude) {
    // Adjust size based on zoom level
    double baseSize = zoomLevel * 3;

    // Optionally adjust based on altitude
    if (altitude != null) {
      baseSize = baseSize * (1 + (altitude / 10000)); // Tweak the divisor to control sensitivity
    }

    // Clamp the size to prevent it from getting too small or too large
    return baseSize.clamp(10.0, 80.0);
  }

  // Function to fetch airplane data with Basic Authentication
  Future<void> fetchAirplanes() async {
    final String url = 'https://opensky-network.org/api/states/all';

    // Encode the username and password as Base64 for Basic Authentication
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    final response = await http.get(
      Uri.parse(url),
      headers: <String, String>{
        'Authorization': basicAuth,  // Add the Authorization header
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<Marker> markers = [];

      for (var airplane in data['states']) {
        double? lat = airplane[6];
        double? lng = airplane[5];
        String? callsign = airplane[1];
        double? heading = airplane[10];
        double? altitude = airplane[13];
        double? velocity = airplane[9];

        if (callsign != null && callsign.startsWith("AFR")) {
          if (lat != null && lng != null && heading != null) {
            markers.add(
              Marker(
                width: 40.0,
                height: 40.0,
                point: LatLng(lat, lng),
                builder: (ctx) {
                  bool isHovered = hoverStates[callsign] ?? false; // Check hover state
                  Color markerColor = isHovered ? Color(0xFF931116) : Color(0xFF002157); // Change color on hover

                  return MouseRegion(
                    onEnter: (_) {
                      setState(() {
                        hoverStates[callsign] = true; // Set hover state to true
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        hoverStates[callsign] = false; // Set hover state to false
                      });
                    },
                    child: Transform.rotate(
                      angle: heading * (3.14159 / 180), // Rotate based on heading (convert degrees to radians)
                      child: Tooltip(
                        message: 'Vol numéro : $callsign\nVitesse : ${velocity?.toStringAsFixed(2) ?? 'N/A'} m/s \nAltitude : $altitude m',
                        child: IconButton(
                          icon: Icon(Icons.airplanemode_active, color: markerColor, size: _calculateIconSize(zoomLevel, altitude)),
                          onPressed: () {
                            // Handle on press if needed
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }
        }
      }

      setState(() {
        airplaneMarkers = markers;
      });
    } else {
      throw Exception('Failed to load airplanes');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 250,
          padding: EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Flight Search Text Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Flight Search',
                  labelStyle: TextStyle(color: Color(0xFF002157)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Color(0xFF002157)),
                  ),
                  suffixIcon: Icon(Icons.search),
                ),
              ),
              SizedBox(height: 24),

              // Flight Company Text Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Origin',
                  labelStyle: TextStyle(color: Color(0xFF002157)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Color(0xFF002157)),
                  ),
                  suffixIcon: Icon(Icons.flight_takeoff),
                ),
              ),
              SizedBox(height: 24),

              // Destination Text Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Destination',
                  labelStyle: TextStyle(color: Color(0xFF002157)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Color(0xFF002157)),
                  ),
                  suffixIcon: Icon(Icons.flight_land),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(0, 0),
                zoom: zoomLevel,
                onPositionChanged: (MapPosition pos, bool hasGesture) {
                  setState(() {
                    zoomLevel = pos.zoom ?? 2.0;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: airplaneMarkers,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
