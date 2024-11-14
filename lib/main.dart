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
              IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {},
              ),
              Container(
                margin: EdgeInsets.only(left: 8.0, right: 8.0),
                child: SvgPicture.asset(
                  'assets/Air_France_Logo.svg', // Path to your SVG logo
                  fit: BoxFit.contain,
                  height: 20,
                ),
              ),
              Spacer(),
              Text(
                'Air France Airplanes Map',
                style: TextStyle(fontSize: 20),
              ),
              Spacer(),
            ],
          ),
          elevation: 0,
          toolbarHeight: 80,
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {},
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
  final MapController mapController = MapController();
  TextEditingController flightSearchController = TextEditingController();

  Map<String, LatLng> flightPositions = {}; // Mapping flight numbers to positions
  Map<String, Map<String, dynamic>> flightInfo = {}; // Mapping flight numbers to additional info

  final String username = 'AzizPistol';
  final String password = 'Ce@Pt37sgNdSiWu';

  @override
  void initState() {
    super.initState();
    fetchAirplanes();
    timer = Timer.periodic(Duration(minutes: 2), (Timer t) => fetchAirplanes());
  }

  @override
  void dispose() {
    timer?.cancel();
    flightSearchController.dispose();
    super.dispose();
  }

  double _calculateIconSize(double zoomLevel, double? altitude) {
    double baseSize = zoomLevel * 3;
    if (altitude != null) {
      baseSize = baseSize * (1 + (altitude / 10000));
    }
    return baseSize.clamp(10.0, 80.0);
  }

  Future<void> fetchAirplanes() async {
    String url = 'https://opensky-network.org/api/states/all';
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    final response = await http.get(
      Uri.parse(url),
      headers: <String, String>{
        'Authorization': basicAuth,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<Marker> markers = [];
      flightPositions.clear();
      flightInfo.clear();

      for (var airplane in data['states']) {
        double? lat = airplane[6];
        double? lng = airplane[5];
        String? callsign = airplane[1];
        double? heading = airplane[10];
        double? altitude = airplane[13];
        double? velocity = airplane[9];

        if (callsign != null && callsign.startsWith("AFR")) {
          callsign = callsign.trim().toUpperCase();
          if (lat != null && lng != null && heading != null) {
            LatLng position = LatLng(lat, lng);
            flightPositions[callsign] = position;
            flightInfo[callsign] = {
              'altitude': altitude,
              'velocity': velocity,
              'heading': heading,
            };

            markers.add(
              Marker(
                width: 40.0,
                height: 40.0,
                point: position,
                builder: (ctx) {
                  return Transform.rotate(
                    angle: heading * (3.14159 / 180),
                    child: Tooltip(
                      message: 'Vol numéro : $callsign\nVitesse : ${velocity?.toStringAsFixed(2) ?? 'N/A'} m/s\nAltitude : $altitude m',
                      child: Icon(
                        Icons.airplanemode_active,
                        color: Color(0xFF002157),
                        size: _calculateIconSize(zoomLevel, altitude),
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

  void focusOnFlight(String flightNumber) {
    String searchKey = flightNumber.trim().toUpperCase();
    LatLng? position = flightPositions[searchKey];
    var info = flightInfo[searchKey];

    if (position != null && info != null) {
      double targetZoom = 8.0; // Niveau de zoom cible
      double step = 0.2; // Pas de zoom progressif
      double currentZoom = mapController.zoom;

      // Crée un timer pour zoomer progressivement
      Timer.periodic(Duration(milliseconds: 40), (timer) {
        if (currentZoom < targetZoom) {
          currentZoom += step; // Augmente le zoom par le pas défini
          mapController.move(position, currentZoom); // Déplace la carte avec le nouveau niveau de zoom
        } else {
          // Arrête le zoom progressif une fois le niveau cible atteint
          timer.cancel();

          // Affiche les infos du vol
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Infos du vol $flightNumber"),
                content: Text(
                  'Vol numéro : $flightNumber\n'
                      'Vitesse : ${info['velocity']?.toStringAsFixed(2) ?? 'N/A'} m/s\n'
                      'Altitude : ${info['altitude']} m',
                ),
                actions: [
                  TextButton(
                    child: Text("Fermer"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
      });
    } else {
      // Affiche un message d'erreur si le vol n'est pas trouvé
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vol $flightNumber non trouvé')),
      );
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
              TextField(
                controller: flightSearchController,
                decoration: InputDecoration(
                  labelText: 'Flight Search',
                  labelStyle: TextStyle(color: Color(0xFF002157)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Color(0xFF002157)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () {
                      focusOnFlight(flightSearchController.text);
                    },
                  ),
                ),
                onSubmitted: (text) {
                  focusOnFlight(text);
                },
              ),
              SizedBox(height: 24),
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
              mapController: mapController,
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
