import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: Scaffold(
        backgroundColor: Color(0xFF002157),
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {},
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8.0),
                child: SvgPicture.asset(
                  'assets/Air_France_Logo.svg',
                  fit: BoxFit.contain,
                  height: 20,
                ),
              ),
              Spacer(),
              Text('Air France Airplanes Map', style: TextStyle(fontSize: 20)),
              Spacer(),
            ],
          ),
          elevation: 0,
          toolbarHeight: 80,
          actions: [
            IconButton(icon: Icon(Icons.search), onPressed: () {}),
            IconButton(icon: Icon(Icons.settings), onPressed: () {}),
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
  final String openSkyUsername = 'luap';
  final String openSkyPassword = 'Luapk989#';
  final String openCageApiKey = '410626e2ecdb40ecad917ea98f71a8be';

  List<Marker> airplaneMarkers = [];
  double zoomLevel = 2.0;
  Timer? timer;
  Map<String, String> locationCache = {}; // Cache pour stocker les géolocalisations

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
    double baseSize = 10 + (zoomLevel * 2);
    if (altitude != null) baseSize += altitude / 10000;
    return baseSize.clamp(8.0, 30.0);
  }

  Future<void> fetchAirplanes() async {
    final urlOpenSky = 'https://opensky-network.org/api/states/all';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$openSkyUsername:$openSkyPassword'));

    try {
      final response = await http
          .get(Uri.parse(urlOpenSky), headers: {'Authorization': basicAuth})
          .timeout(Duration(seconds: 10)); // Timeout ajouté

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Marker> markers = [];

        for (var airplane in data['states']) {
          String? icao24 = airplane[0]?.toLowerCase();
          String? callsign = airplane[1];
          double? lat = airplane[6];
          double? lng = airplane[5];
          double? heading = airplane[10];
          double? altitude = airplane[13];

          if (callsign != null && callsign.startsWith("AFR") && icao24 != null) {
            markers.add(
              Marker(
                width: 60.0,
                height: 60.0,
                point: LatLng(lat ?? 0, lng ?? 0),
                builder: (ctx) => GestureDetector(
                  onTap: () => fetchFlightDetails(context, icao24),
                  child: Transform.rotate(
                    angle: heading != null ? heading * (3.14159 / 180) : 0.0,
                    child: Icon(
                      Icons.airplanemode_active,
                      color: Color(0xFF002157),
                      size: _calculateIconSize(zoomLevel, altitude),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        setState(() {
          airplaneMarkers = markers;
        });
      } else {
        print("Failed to fetch airplanes: ${response.body}");
      }
    } on TimeoutException catch (_) {
      print("La requête OpenSky a expiré.");
    } catch (e) {
      print("Error fetching airplanes: $e");
    }
  }

  Future<Map<String, dynamic>> getFlightPositions(String icao24) async {
    final url = 'https://opensky-network.org/api/tracks/all?icao24=$icao24&time=0';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$openSkyUsername:$openSkyPassword'));

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': basicAuth})
          .timeout(Duration(seconds: 10)); // Timeout ajouté

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['path'] != null && data['path'].isNotEmpty) {
          final departure = data['path'].first;
          final arrival = data['path'].last;

          return {
            'departure': {'lat': departure[1], 'lng': departure[2]},
            'arrival': {'lat': arrival[1], 'lng': arrival[2]},
          };
        }
      }
    } on TimeoutException catch (_) {
      print("La requête pour les positions a expiré.");
    } catch (e) {
      print("Error fetching flight positions: $e");
    }

    return {};
  }

  Future<void> fetchFlightDetails(BuildContext context, String icao24) async {
    final positions = await getFlightPositions(icao24);

    if (positions.isEmpty ||
        positions['departure'] == null ||
        positions['arrival'] == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Détails de l\'avion'),
          content: Text('Les informations de départ ou d\'arrivée ne sont pas disponibles.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    final departureLocation = await getLocationDetails(
      positions['departure']['lat'],
      positions['departure']['lng'],
    );
    final arrivalLocation = await getLocationDetails(
      positions['arrival']['lat'],
      positions['arrival']['lng'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails de l\'avion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ICAO24: $icao24'),
            Text('Lieu de départ : $departureLocation'),
            Text('Lieu d\'arrivée : $arrivalLocation'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<String> getLocationDetails(double lat, double lng) async {
    String key = "$lat,$lng";

    if (locationCache.containsKey(key)) {
      return locationCache[key]!;
    }

    final url =
        'https://api.opencagedata.com/geocode/v1/json?q=$lat+$lng&key=$openCageApiKey';

    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final components = data['results'][0]['components'];
          final city = components['city'] ??
              components['town'] ??
              components['village'] ??
              components['hamlet'];
          final country = components['country'];

          if (city != null && country != null) {
            String location = '$city, $country';
            locationCache[key] = location; // Ajout au cache
            return location;
          }
        }
      }
    } on TimeoutException catch (_) {
      print("La requête OpenCageData a expiré.");
    } catch (e) {
      print("Erreur lors de la récupération des détails : $e");
    }

    return "Inconnu";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: FlutterMap(
            options: MapOptions(
              center: LatLng(48.8566, 2.3522),
              zoom: zoomLevel,
              onTap: (tapPosition, point) {
                print("Carte cliquée à : $point");
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: airplaneMarkers),
            ],
          ),
        ),
      ],
    );
  }
}