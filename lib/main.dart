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
  Map<String, bool> hoverStates = {}; // Store hover states

  final String openSkyUsername = 'luap';
  final String openSkyPassword = 'Luapk989#';
  final String openCageApiKey = '410626e2ecdb40ecad917ea98f71a8be';

  List<Marker> airplaneMarkers = [];
  double zoomLevel = 2.0;
  Timer? timer;
  Map<String, String> locationCache = {}; // Cache pour stocker les géolocalisations

  final MapController mapController = MapController();
  Map<String, LatLng> flightPositions = {};
  Map<String, Map<String, dynamic>> flightInfo = {};
  TextEditingController flightSearchController = TextEditingController();
  TextEditingController originController = TextEditingController();
  TextEditingController destinationController = TextEditingController();

  // Placez la méthode `filterByCity` ici
  void filterByCity(String cityName, bool isOrigin) async {
    if (cityName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Veuillez entrer une ville valide.")),
      );
      return;
    }

    Map<String, String> filteredFlights = {};

    for (var callsign in flightInfo.keys) {
      final info = flightInfo[callsign];
      if (info == null) continue;

      final icao24 = info['icao24'];
      if (icao24 == null) continue;

      final positions = await getFlightPositions(icao24);
      if (positions.isEmpty) continue;

      final location = await getLocationDetails(
        positions[isOrigin ? 'departure' : 'arrival']['lat'],
        positions[isOrigin ? 'departure' : 'arrival']['lng'],
      );

      if (location.toLowerCase().contains(cityName.toLowerCase())) {
        filteredFlights[callsign] = location;
      }
    }

    if (filteredFlights.isNotEmpty) {
      List<Marker> markers = [];

      for (var callsign in filteredFlights.keys) {
        final position = flightPositions[callsign];
        final info = flightInfo[callsign];
        if (position == null || info == null) continue;

        markers.add(
          Marker(
            width: 60.0,
            height: 60.0,
            point: position,
            builder: (ctx) {
              return Transform.rotate(
                angle: (info['heading'] ?? 0) * (3.14159 / 180),
                child: Tooltip(
                  message:
                  'Vol numéro : $callsign\nLieu : ${filteredFlights[callsign]}',
                  child: Icon(
                    Icons.airplanemode_active,
                    color: Color(0xFF002157),
                    size: _calculateIconSize(zoomLevel, info['altitude']),
                  ),
                ),
              );
            },
          ),
        );
      }

      setState(() {
        airplaneMarkers = markers;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aucun vol trouvé pour $cityName.")),
      );
    }
  }

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
    originController.dispose();
    destinationController.dispose();
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
        flightPositions.clear();
        flightInfo.clear();

        for (var airplane in data['states']) {
          String? icao24 = airplane[0]?.toLowerCase(); // Identifiant unique
          String? callsign = airplane[1]?.trim().toUpperCase(); // Numéro de vol
          double? lat = airplane[6];
          double? lng = airplane[5];
          double? heading = airplane[10];
          double? altitude = airplane[13];
          double? velocity = airplane[9];

          if (callsign != null && callsign.startsWith("AFR") && icao24 != null) {
            LatLng position = LatLng(lat ?? 0, lng ?? 0);
            flightPositions[callsign] = position;
            flightInfo[callsign] = {
              'altitude': altitude,
              'velocity': velocity,
              'heading': heading,
              'icao24': icao24,
            };

            // Ajouter le marker avec un Tooltip
            markers.add(
              Marker(
                width: 27.0,
                height: 27.0,
                point: LatLng(lat ?? 0.0, lng ?? 0.0),
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
                      angle: (heading ?? 0.0) * (3.14159 / 180), // Rotate based on heading (convert degrees to radians)
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

  Future<void> focusOnFlight(String flightNumber) async {
    String searchKey = flightNumber.trim().toUpperCase();
    LatLng? position = flightPositions[searchKey];
    var info = flightInfo[searchKey];

    if (position != null && info != null) {
      double targetZoom = 8.0; // Niveau de zoom cible
      double step = 0.2; // Pas de zoom progressif
      double currentZoom = mapController.zoom;

      // Récupérer les détails via l'API OpenCage
      final positions = await getFlightPositions(info['icao24']);
      final departureLocation = await getLocationDetails(
        positions['departure']['lat'],
        positions['departure']['lng'],
      );
      final arrivalLocation = await getLocationDetails(
        positions['arrival']['lat'],
        positions['arrival']['lng'],
      );

      // Démarrer un zoom progressif
      Timer.periodic(Duration(milliseconds: 50), (timer) {
        if (currentZoom < targetZoom) {
          currentZoom += step; // Augmenter le niveau de zoom
          mapController.move(position, currentZoom); // Centrer sur l'avion
        } else {
          timer.cancel(); // Arrêter une fois le zoom cible atteint

          // Afficher les détails une fois le zoom terminé
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Infos du vol $flightNumber"),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Numéro : $flightNumber'),
                    Text('Vitesse : ${info['velocity']?.toStringAsFixed(2) ?? 'N/A'} m/s'),
                    Text('Altitude : ${info['altitude']} m'),
                    Text('Départ : $departureLocation'),
                    Text('Arrivée : $arrivalLocation'),
                  ],
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
      // Afficher une notification si le vol est introuvable
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
                controller: originController, // Ajouter un contrôleur pour récupérer la saisie
                decoration: InputDecoration(
                  labelText: 'Origin',
                  labelStyle: TextStyle(color: Color(0xFF002157)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Color(0xFF002157)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () {
                      // Appeler la méthode filterByCity pour la recherche par ville d'origine
                      filterByCity(originController.text, true);
                    },
                  ),
                ),
                onSubmitted: (text) {
                  // Appeler la méthode filterByCity lorsque l'utilisateur appuie sur Entrée
                  filterByCity(text, true);
                },
              ),
              SizedBox(height: 24),
              TextField(
                controller: destinationController, // Ajouter un contrôleur pour récupérer la saisie
                decoration: InputDecoration(
                  labelText: 'Destination',
                  labelStyle: TextStyle(color: Color(0xFF002157)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Color(0xFF002157)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () {
                      // Appeler la méthode filterByCity pour la recherche par ville d'arrivée
                      filterByCity(destinationController.text, false);
                    },
                  ),
                ),
                onSubmitted: (text) {
                  // Appeler la méthode filterByCity lorsque l'utilisateur appuie sur Entrée
                  filterByCity(text, false);
                },
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

    // Appels OpenCage
    final departureLocation = await getLocationDetails(
      positions['departure']['lat'],
      positions['departure']['lng'],
    );
    final arrivalLocation = await getLocationDetails(
      positions['arrival']['lat'],
      positions['arrival']['lng'],
    );

    // Affichage
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
}
