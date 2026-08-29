import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SyncBeatApp());
}

class SyncBeatApp extends StatelessWidget {
  const SyncBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SyncBeat',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SyncBeat - Universal Music Sync')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_filled, size: 80, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                'Paste YouTube URL & Play Together',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.deepPurple,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Sync Room', style: TextStyle(fontSize: 18)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RoomScreen(isHost: true)),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.grey[800],
                ),
                icon: const Icon(Icons.login),
                label: const Text('Join Room with Code', style: TextStyle(fontSize: 18)),
                onPressed: () {
                  _showJoinDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter 4-Digit Room Code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(hintText: 'e.g. 5678'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length == 4) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomScreen(isHost: false, roomCode: controller.text),
                  ),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  final bool isHost;
  final String? roomCode;

  const RoomScreen({super.key, required this.isHost, this.roomCode});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late String roomCode;
  YoutubePlayerController? _controller;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _urlController = TextEditingController();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    roomCode = widget.roomCode ?? (1000 + Random().nextInt(9000)).toString();
    if (widget.isHost) {
      _initRoom();
    }
    _listenToRoom();
  }

  void _initRoom() {
    _dbRef.child('rooms/$roomCode').set({
      'videoId': 'jfKfPfyJRdk',
    });
  }

  void _initializePlayer(String videoId) {
    if (_isDisposed) return;
    if (_controller == null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      );
      if (mounted) setState(() {});
    } else {
      if (_controller!.metadata.videoId != videoId) {
        _controller!.load(videoId);
      }
    }
  }

  void _listenToRoom() {
    _dbRef.child('rooms/$roomCode').onValue.listen((event) {
      if (_isDisposed) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['videoId'] != null) {
        String videoId = data['videoId'];
        _initializePlayer(videoId);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room Code: $roomCode')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_controller != null)
              YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.redAccent,
                ),
                builder: (context, player) {
                  return Column(
                    children: [
                      player,
                      const SizedBox(height: 20),
                    ],
                  );
                },
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: CircularProgressIndicator(),
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Paste YouTube URL here',
                hintText: 'https://youtube.com/watch?v=...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _urlController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.redAccent,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Song on All Devices', style: TextStyle(fontSize: 16)),
              onPressed: () {
                String? videoId = YoutubePlayer.convertUrlToId(_urlController.text);
                if (videoId != null) {
                  _dbRef.child('rooms/$roomCode').update({
                    'videoId': videoId,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Song updated across all devices!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid YouTube URL. Please check and try again.')),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  widget.isHost
                      ? 'Share Room Code "$roomCode" with friends so they can paste links or listen along.'
                      : 'You are synced to the room. Whenever a URL is played, your device will stream it automatically.',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  final bool isHost;
  final String? roomCode;

  const RoomScreen({super.key, required this.isHost, this.roomCode});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late String roomCode;
  YoutubePlayerController? _controller;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _urlController = TextEditingController();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    roomCode = widget.roomCode ?? (1000 + Random().nextInt(9000)).toString();
    if (widget.isHost) {
      _initRoom();
    }
    _listenToRoom();
  }

  void _initRoom() {
    _dbRef.child('rooms/$roomCode').set({
      'videoId': 'jfKfPfyJRdk', // Default track
    });
  }

  void _initializePlayer(String videoId) {
    if (_isDisposed) return;
    if (_controller == null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      );
      if (mounted) setState(() {});
    } else {
      if (_controller!.metadata.videoId != videoId) {
        _controller.load(videoId);
      }
    }
  }

  void _listenToRoom() {
    _dbRef.child('rooms/$roomCode').onValue.listen((event) {
      if (_isDisposed) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['videoId'] != null) {
        String videoId = data['videoId'];
        _initializePlayer(videoId);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room Code: $roomCode')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_controller != null)
              YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.redAccent,
                ),
                builder: (context, player) {
                  return Column(
                    children: [
                      player,
                      const SizedBox(height: 20),
                    ],
                  );
                },
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: CircularProgressIndicator(),
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Paste YouTube URL here',
                hintText: 'https://youtube.com/watch?v=...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _urlController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.redAccent,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Song on All Devices', style: TextStyle(fontSize: 16)),
              onPressed: () {
                String? videoId = YoutubePlayer.convertUrlToId(_urlController.text);
                if (videoId != null) {
                  // Push to Firebase so all devices load and play this exact song
                  _dbRef.child('rooms/$roomCode').update({
                    'videoId': videoId,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Song updated across all devices!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid YouTube URL. Please check and try again.')),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  widget.isHost
                      ? 'Share Room Code "$roomCode" with friends so they can paste links or listen along.'
                      : 'You are synced to the room. Whenever a URL is played, your device will stream it automatically.',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  final bool isHost;
  final String? roomCode;

  const RoomScreen({super.key, required this.isHost, this.roomCode});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late String roomCode;
  YoutubePlayerController? _controller;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _urlController = TextEditingController();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    roomCode = widget.roomCode ?? (1000 + Random().nextInt(9000)).toString();
    if (widget.isHost) {
      _initRoom();
    } else {
      _listenToRoom();
    }
  }

  void _initRoom() {
    _dbRef.child('rooms/$roomCode').set({
      'videoId': 'jfKfPfyJRdk',
      'isPlaying': false,
      'position': 0,
    });
  }

  void _loadVideo(String videoId) {
    if (_controller == null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    } else {
      _controller!.load(videoId);
    }
    setState(() {});
  }

  void _listenToRoom() {
    _dbRef.child('rooms/$roomCode').onValue.listen((event) {
      if (_isDisposed) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        String videoId = data['videoId'] ?? 'jfKfPfyJRdk';
        bool isPlaying = data['isPlaying'] ?? false;

        if (_controller == null) {
          _loadVideo(videoId);
        } else if (_controller!.metadata.videoId != videoId) {
          _controller!.load(videoId);
        }

        if (isPlaying && _controller!.value.playerState != PlayerState.playing) {
          _controller!.play();
        } else if (!isPlaying && _controller!.value.playerState == PlayerState.playing) {
          _controller!.pause();
        }
      }
    });
  }

  void _updateDatabase({required String videoId, required bool isPlaying}) {
    if (widget.isHost) {
      _dbRef.child('rooms/$roomCode').update({
        'videoId': videoId,
        'isPlaying': isPlaying,
        'position': _controller?.value.position.inMilliseconds ?? 0,
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room: $roomCode (${widget.isHost ? "Host" : "Listener"})')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_controller != null)
              YoutubePlayer(
                controller: _controller!,
                showVideoProgressIndicator: true,
              )
            else
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            if (widget.isHost) ...[
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Paste YouTube URL or ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  String? videoId = YoutubePlayer.convertUrlToId(_urlController.text);
                  if (videoId != null) {
                    _loadVideo(videoId);
                    _updateDatabase(videoId: videoId, isPlaying: true);
                  }
                },
                child: const Text('Play & Sync Song'),
              ),
            ] else ...[
              const Text(
                'Connected as Listener. Waiting for host actions...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
